```@meta
CurrentModule = PathCompleteCertificates
```

# Choosing a graph

```@setup running
using PathCompleteCertificates
import Clarabel
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = switched_system(A)
problem = StabilityProblem(system)
```

The graph gives the structure of the program that [`certify`](@ref) solves:
one node function per node, and one edge inequality per edge. Along a
trajectory, a path of the graph that reads its modes says which node function
applies at each step. With the template, the graph influences how good the
certificate can be and how much it costs (see [How a certificate works](@ref)).
This page defines the property every graph must have, presents the classical
graphs, and shows how to build your own.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = StabilityProblem(system)`, solved with Clarabel.

## Path-complete, complete and co-complete graphs

A graph ``G = (S, E)`` on the modes ``\{1, \dots, M\}`` has nodes ``S`` and
edges ``(s, d, i) \in E``, from ``s`` to ``d``, labelled by mode ``i``. It is
**path-complete** when every sequence of modes is read along some path of it
[ahmadi2014joint; Def. 2.2](@cite): for every ``i_1, \dots, i_k``, there are
nodes ``s_0, \dots, s_k`` with ``(s_{j-1}, s_j, i_j) \in E`` for every ``j``.

[`is_path_complete`](@ref) decides it by the subset construction: start from
the set of all nodes, let each mode map a set of nodes to the nodes its edges
reach, and the graph is path-complete exactly when the empty set is never
reached [abate2026succinct; Prop. 3.1](@cite). Two stronger properties are
cheap to check, and `is_path_complete` tries them first:

- **complete:** every node has an outgoing edge for every mode,
  [`is_complete`](@ref).
- **co-complete:** every node has an incoming edge for every mode,
  [`is_co_complete`](@ref).

[`certify`](@ref) checks that the graph is path-complete before solving, and
throws if not. Optimal control needs more, a complete graph (see
[What works with what](@ref)). A certificate on a graph that is not
path-complete would prove the property only for the sequences the graph
reads.

!!! warning "The check can be costly"
    Deciding path-completeness is PSPACE-complete in general, as recalled in
    [abate2026succinct](@cite): the subset construction can visit
    exponentially many sets, so on a large graph that is neither complete nor
    co-complete, the check before solving can take long.
    The keyword `check_path_complete = false` of `certify`, for stability
    and safety, and of `refine` skips it, for a graph you know to be
    path-complete.

## Classical graphs

### The common graph

[`common_graph`](@ref)`(system)` has one node and a loop per mode. Its
certificate is a single function that satisfies the edge inequality for every
mode, for stability a common Lyapunov function. Start here.

### De Bruijn graphs

The De Bruijn graph of order ``k`` on ``M`` modes,
[`de_bruijn`](@ref)`(k, M)`, has one node per sequence of ``k`` modes, so
``M^k`` nodes, and the edges

```math
\big((j_1, \dots, j_k),\ (i, j_1, \dots, j_{k-1}),\ i\big)
\qquad \text{for all modes } i, j_1, \dots, j_k.
```

A node is a **memory of the past**: the last ``k`` modes read, ``j_1`` the
most recent, so the edge labelled ``i`` enters a node whose latest mode is
``i``. The graph is complete. Its **dual**, [`dual`](@ref)`(de_bruijn(k, M))`,
reverses every edge. It is co-complete, and a node is a **prediction of the
future**: the next ``k`` modes, so the edge labelled ``i`` leaves a node whose
next mode is ``i``. The common graph is the De Bruijn graph of order 0. With
two modes, the graphs of order 0 and 1:

```@setup running
include(joinpath(pkgdir(PathCompleteCertificates), "docs", "graph_drawing.jl"))

const PAIR = [(-0.9, 0.0), (0.9, 0.0)]

function de_bruijn_figure()
    return plot(draw_graph(de_bruijn(0, 2), [(0.0, 0.0)]; title = "common graph"),
                draw_graph(de_bruijn(1, 2), PAIR; title = "De Bruijn, order 1"),
                draw_graph(dual(de_bruijn(1, 2)), PAIR; title = "dual, order 1");
                layout = (1, 3), size = (900, 200))
end
```

```@example running
de_bruijn_figure() # hide
```

At order 1, a node is one mode: the edge labelled ``i`` enters node ``i`` in
the De Bruijn graph, and leaves it in its dual.

### The De Bruijn hierarchy

Each order simulates the next, so each order gives a certificate at least as
good as the one before, for every template (see [Comparing graphs](@ref)). The
price is the size: order ``k`` has ``M^k`` nodes and ``M^{k+1}`` edges, so
each order multiplies the variables and the constraints of the program by
``M``. The bounds for the first orders:

```@example running
template = QuadraticTemplate()
rate(graph) = certify(template, graph, problem; optimizer = Clarabel.Optimizer).rate

for k in 0:4
    primal = de_bruijn(k, 2)
    println("order ", k, ": ", n_nodes(primal), " nodes, rates ",
            round.((rate(primal), rate(dual(primal))); digits = 4))
end
```

On this system, a graph and its dual give the same bounds. Beyond order 2,
the bound stops improving while the graphs keep growing: orders 3 and 4 each
double the nodes for the same bound. The hierarchy adds nodes everywhere at
once, whether they help or not. The end of this page shows a smaller graph
that reaches the same bound.

## Your own graph

[`empty_graph`](@ref)`(n)` creates a graph with `n` nodes, and
[`add_edge!`](@ref)`(graph, s, d, i)` adds an edge from node `s` to node `d`
labelled by mode `i`. For instance, the De Bruijn graph of order 1, by hand:

```@example running
graph = empty_graph(2)
for (s, d, i) in [(1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2)]
    add_edge!(graph, s, d, i)
end
is_path_complete(graph, 1:n_modes(system))
```

Without the loop labelled 2 at node 2, no path reads the sequence ``2, 2``,
and the graph is no longer path-complete:

```@example running
partial = empty_graph(2)
for (s, d, i) in [(1, 1, 1), (1, 2, 2), (2, 1, 1)]
    add_edge!(partial, s, d, i)
end
is_path_complete(partial, 1:n_modes(system))
```

```@example running
plot(draw_graph(graph, PAIR; title = "path-complete"), # hide
     draw_graph(partial, PAIR; title = "not path-complete"); # hide
     layout = (1, 2), size = (600, 200)) # hide
```

Always pass the modes of the system, `1:n_modes(system)`: without them,
`is_path_complete` only asks about the modes the graph happens to use.

### Words on the edges

In a [`WordGraph`](@ref), an edge can read a sequence of modes, and imposes one
inequality on the product of their matrices. Words are supported for
stability only (see [What works with what](@ref)). [`expanded_form`](@ref)
gives a graph that reads the same sequences with one mode per edge, and the
graph is path-complete exactly when its expanded form is
[ahmadi2014joint; Defs. 2.1 and 2.2](@cite).

## Not sure which graph to use?

Let the package design one. Starting from the common graph,
[`refine`](@ref) adds nodes only where the certificate is tight, and on this
system reaches the bound of order 2 with a smaller graph: see
[Refining the graph](@ref). To know whether one graph is at least as good as
another, without computing any certificate, see [Comparing graphs](@ref).
