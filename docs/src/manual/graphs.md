```@meta
CurrentModule = PathCompleteCertificates
```

# Choosing a graph

```@setup running
import PathCompleteCertificates as PCC
import Clarabel
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)
```

The graph decides which node function applies at each step of a trajectory.
This page presents the classical graphs, how to build your own, and how a
graph is checked.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = PCC.StabilityProblem(system)`, solved with Clarabel.

## Classical graphs

### The one-node graph

[`common_graph`](@ref)`(system)` has one node and a loop per mode. Its
certificate is a single function that satisfies the edge inequality for every
mode; for stability, a common Lyapunov function. Start here.

### De Bruijn graphs

[`de_bruijn`](@ref)`(k, M)` has one node per sequence of ``k`` modes, so
``M^k`` nodes for ``M`` modes, in two versions:

- **primal, a memory of the past:** in `de_bruijn(k, M)`, a node stands for
  the last ``k`` modes read, so the edge reading mode ``i`` enters a node whose
  latest mode is ``i``;
- **dual, a prediction of the future:** [`dual`](@ref)`(de_bruijn(k, M))`
  reverses every edge, so a node stands for the next ``k`` modes, and the edge
  reading mode ``i`` leaves a node whose next mode is ``i``.

With two modes, the one-node graph and the two graphs of order 1:

```@setup running
using Plots

const MODE_COLORS = [:royalblue, :darkorange]

# A drawing of a graph with two modes, its nodes at the given positions.
function draw_graph(graph, positions; title)
    panel = plot(; aspect_ratio = :equal, framestyle = :none, legend = false, title,
                 titlefontsize = 10, xlims = (-1.6, 1.6), ylims = (-1.1, 1.3))
    for edge in PCC.edges(graph)
        a, b = PCC.source(edge), PCC.dest(edge)
        mode = only(PCC.letters(PCC.label(graph, edge)))
        color = MODE_COLORS[mode]
        if a == b
            # A loop, above the node for mode 1 and below it for mode 2.
            x, y = positions[a]
            side = mode == 1 ? 1 : -1
            t = range(-0.85pi, 0.85pi; length = 50)
            plot!(panel, x .+ 0.32 .* sin.(t), y .+ side .* (0.38 .+ 0.32 .* cos.(t));
                  color, lw = 2, arrow = arrow(:closed, 0.25, 0.25))
            annotate!(panel, x, y + side * 0.85, text("$mode", 10, color))
        else
            # An arc bent to the left of its direction, so that opposite edges part.
            (x1, y1), (x2, y2) = positions[a], positions[b]
            cx, cy = (x1 + x2) / 2 - 0.25 * (y2 - y1), (y1 + y2) / 2 + 0.25 * (x2 - x1)
            s = range(0.12, 0.88; length = 50)
            xs = (1 .- s) .^ 2 .* x1 .+ 2 .* (1 .- s) .* s .* cx .+ s .^ 2 .* x2
            ys = (1 .- s) .^ 2 .* y1 .+ 2 .* (1 .- s) .* s .* cy .+ s .^ 2 .* y2
            plot!(panel, xs, ys; color, lw = 2, arrow = arrow(:closed, 0.25, 0.25))
            annotate!(panel, cx, cy + 0.12 * sign(x2 - x1), text("$mode", 10, color))
        end
    end
    for (node, (x, y)) in enumerate(positions)
        scatter!(panel, [x], [y]; markersize = 16, color = :white, markerstrokewidth = 2)
        annotate!(panel, x, y, text("$node", 10))
    end
    return panel
end

function de_bruijn_figure()
    pair = [(-0.9, 0.0), (0.9, 0.0)]
    return plot(draw_graph(PCC.de_bruijn(0, 2), [(0.0, 0.0)]; title = "one node"),
                draw_graph(PCC.de_bruijn(1, 2), pair; title = "primal, order 1"),
                draw_graph(PCC.dual(PCC.de_bruijn(1, 2)), pair; title = "dual, order 1");
                layout = (1, 3), size = (900, 290))
end
```

```@example running
de_bruijn_figure() # hide
```

In the primal graph, the edge reading mode ``i`` enters node ``i``: the node
is the last mode read. In the dual graph, it leaves node ``i``: the node is
the next mode.

### The De Bruijn hierarchy

The one-node graph is the De Bruijn graph of order 0. Each order simulates the
next, so each order gives a bound at least as good as the one before, for
every template (see [Comparing graphs](@ref)). The price is ``M`` times more
nodes, and each node adds a function to find and each edge an inequality, so
the program grows with the order. The bounds for the first orders:

```@example running
template = PCC.QuadraticTemplate()
rate(graph) = PCC.certify(template, graph, problem; optimizer = Clarabel.Optimizer).rate

for k in 0:4
    primal = PCC.de_bruijn(k, 2)
    println("order ", k, ": ", PCC.n_nodes(primal), " nodes, rates ",
            round.((rate(primal), rate(PCC.dual(primal))); digits = 4))
end
```

On this system, the primal and dual hierarchies give the same bounds. Beyond
order 2, they only grow: order 3 doubles the nodes for the same bound, and so
does order 4. The hierarchy adds nodes everywhere at once, whether they help
or not; the end of this page shows a smaller graph that reaches the same
bound.

## Your own graph

[`empty_graph`](@ref)`(n)` creates a graph with `n` nodes, and
[`add_edge!`](@ref)`(graph, a, b, i)` adds an edge from node `a` to node `b`
reading mode `i`. For instance, the primal De Bruijn graph of order 1, by
hand:

```@example running
graph = PCC.empty_graph(2)
PCC.add_edge!(graph, 1, 1, 1)
PCC.add_edge!(graph, 1, 2, 2)
PCC.add_edge!(graph, 2, 1, 1)
PCC.add_edge!(graph, 2, 2, 2)
PCC.is_path_complete(graph, 1:PCC.n_modes(system))
```

Without the loop reading mode 2 at node 2, no path reads the sequence
``2, 2``, and the graph is no longer path-complete:

```@example running
partial = PCC.empty_graph(2)
PCC.add_edge!(partial, 1, 1, 1)
PCC.add_edge!(partial, 1, 2, 2)
PCC.add_edge!(partial, 2, 1, 1)
PCC.is_path_complete(partial, 1:PCC.n_modes(system))
```

### Words on the edges

In a [`WordGraph`](@ref), an edge can read a sequence of modes, and imposes one
inequality on the product of their matrices. Words are supported for
stability only. [`expanded_form`](@ref) gives a graph that reads the same
sequences with one mode per edge.

## Checking a graph

Before solving, stability and safety check that the graph is path-complete
for the system's modes, and optimal control that it is complete; each throws
if not. A certificate on a graph that is not path-complete would prove the
property only for the sequences the graph reads.

!!! warning
    `is_path_complete(graph)` alone asks about the modes the graph uses, so a
    graph that never reads a mode passes. Ask about the system's modes:
    `is_path_complete(graph, 1:n_modes(system))`.

A graph is **complete** when every node has an outgoing edge for every mode,
and **co-complete** when every node has an incoming edge for every mode. Both
imply path-completeness and are cheap to check, with [`is_complete`](@ref)
and [`is_co_complete`](@ref). Primal De Bruijn graphs are complete, so they
suit optimal control, and dual ones are co-complete.

Deciding path-completeness can be slow on large graphs.
`check_path_complete = false` skips the check, for a graph you know to be
path-complete.

## Not sure which graph to use?

Let the package design one. Starting from the one-node graph,
[`refine`](@ref) adds nodes only where the certificate is tight. On this
system, it reaches the bound of order 2 with 3 nodes and 6 edges, instead of
4 nodes and 8 edges: see [Refining the graph](@ref).
