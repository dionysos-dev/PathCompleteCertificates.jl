```@meta
CurrentModule = PathCompleteCertificates
```

# Refining the graph

```@setup running
using PathCompleteCertificates
import Clarabel
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = switched_system(A)
problem = StabilityProblem(system)
```

The graph influences how good the certificate can be and how much it costs,
and a generic graph pays for nodes everywhere: the De Bruijn graph of order
``k`` has ``M^k`` nodes whatever the system, and on the running example,
orders 3 and 4 double the nodes for no better bound (see
[Choosing a graph](@ref)). [Comparing graphs](@ref) tells that a graph is
never worse than another, not which graph suits the system at hand.
Refinement builds the graph for the system, from its own certificate
[athanasopoulos2019polyhedral, ninite2026lifting](@cite). It runs on stability
only.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = StabilityProblem(system)`, solved with Clarabel.

## The loop

Refinement lifts the graph at the **tight edges** of its certificate, those
whose edge inequality is active (see [Reading a certificate](@ref)). From a
path-complete graph ``G_0``, by default the common graph, step ``t``:

1. computes the best rate ``\gamma_t`` on ``G_t``, with the template.
2. stops if ``\gamma_t`` is proved optimal, or no longer improves.
3. reads the tight edges of the certificate on ``G_t``.
4. lifts ``G_t`` where the algorithm chooses from them, into ``G_{t+1}``, and
   stops if the algorithm finds nowhere to lift.

With the two algorithms of the package, every step is a split or a product,
valid for every template (see [Lifts](@ref)), so the rate never increases, up
to the bisection tolerance. A lifted graph is path-complete without a new
check: path-completeness is checked on the first graph only.

## In one call

[`refine`](@ref)`(template, problem; optimizer)` runs the loop from the
common graph, and `refine(template, graph, problem; optimizer)` from your
graph:

```@example running
trace = refine(QuadraticTemplate(), problem; optimizer = Clarabel.Optimizer)
rates(trace), n_nodes.(graphs(trace)), n_edges.(graphs(trace))
```

In two steps, the rate drops from about ``0.959`` to ``0.869`` with 3 nodes
and 6 edges. The De Bruijn hierarchy needs order 2, with 4 nodes and 8 edges,
for the same bound:

```@example running
order_2 = de_bruijn(2, 2)
rate = certify(QuadraticTemplate(), order_2, problem; optimizer = Clarabel.Optimizer).rate
rate, n_nodes(order_2), n_edges(order_2)
```

## The algorithms

The keyword `algorithm` chooses where to lift.

### Tightest node splitting, the default

[`TightestNodeSplitting`](@ref) follows Algorithm 1 of
[ninite2026lifting](@citet), whose results say where to lift:

- **Only the tight edges matter.** The tight edges alone give the same rate
  [ninite2026lifting; Prop. 1](@cite), so the graph is lifted where they
  are.
- **A node with a single tight outgoing edge is not worth splitting.**
  Splitting it cannot lower the rate [ninite2026lifting; Prop. 3](@cite), and
  a node with two or more may.

So the algorithm splits the node with the most tight outgoing edges, among
those with at least two, into one copy per outgoing edge, with
[`OutSplitLift`](@ref). Among nodes with as many tight edges, it splits the
one with the fewest outgoing edges, which adds the fewest nodes. The split is
finer than in the paper, which makes one copy per out-neighbour, and
Prop. 3 still holds for it. From the common graph, the first step gives the
dual De Bruijn graph of order 1. When no node has two tight outgoing edges,
the rate is the joint spectral radius [ninite2026lifting; Thm. 4](@cite), and
the run stops.

### Best of tight-edge lifts

[`BestOfTightEdgeLifts`](@ref) follows
[athanasopoulos2019polyhedral; Ex. 2](@cite). It applies the four local lifts
of [Lifts](@ref), the splits and the products, at every tight edge, one edge
at a time, solves every candidate graph, and keeps the one with the lowest
rate. A step costs one bisection per candidate, so up to four per tight edge.

### Your own algorithm

A new algorithm subtypes [`AbstractRefinementAlgorithm`](@ref) and
implements [`next_graph`](@ref). From the current certificate, it returns the
next graph, or `nothing` when it finds nowhere to lift, which stops the run:

```julia
import PathCompleteCertificates: next_graph

struct MyAlgorithm <: AbstractRefinementAlgorithm end

function next_graph(::MyAlgorithm, certificate; atol, solve)
    tight = tight_subgraph(certificate; atol)
    L = ...     # a lift, such as OutSplitLift()
    node = ...  # where to apply it, such as a node of `tight`
    return lift(L, get_graph(certificate), node), nothing
end
```

Edges with slack at most `atol` are tight. The next graph comes as a pair.
The first element is the [`Lifted`](@ref) graph. The second is its
certificate, if the algorithm already solved it with `solve`, as
`BestOfTightEdgeLifts` does, or `nothing`, in which case `refine` solves it.
[Extending the package](@ref) says where the file goes.

## When it stops

[`status`](@ref)`(trace)` says why the run stopped:

| Status | The run stopped because |
| :-- | :-- |
| [`OPTIMAL`](@ref) | the rate is proved to be the joint spectral radius, within `gap_tol` |
| [`STALLED`](@ref) | `stall_max` steps in a row did not lower the rate by `rtol` |
| [`DEPTH_REACHED`](@ref) | `depth_max` graphs were visited |
| [`STOPPED`](@ref) | the `stop` predicate held, for example `c -> c.rate < 1` |
| [`EXHAUSTED`](@ref) | the algorithm found no next graph |

```@example running
status(trace)
```

On the running example, the run stops with `OPTIMAL`. On its three nodes,
every node has one tight outgoing edge, so the rate ``0.869`` is the joint
spectral radius of the system, reached and proved in two steps.

## The trace

The [`RefinementTrace`](@ref) keeps every step: [`certificates`](@ref),
[`graphs`](@ref), [`rates`](@ref), and [`steps`](@ref), each step a
[`Lifted`](@ref) graph with the [`origins`](@ref) of its nodes.

!!! note "Tolerances"
    Three tolerances drive the run: `rtol` and `atol`, as for a single
    certificate (see [Reading a certificate](@ref)), and `gap_tol`, the gap
    between the rate and its lower bound at which the run stops.
