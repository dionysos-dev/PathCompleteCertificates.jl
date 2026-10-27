```@meta
CurrentModule = PathCompleteCertificates
```

# Refining the graph

```@setup running
import PathCompleteCertificates as PCC
import Clarabel
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)
```

The graph decides how good the certificate can be and how much it costs, and
a generic graph pays for nodes everywhere: the De Bruijn graph of order ``k``
has ``M^k`` nodes whatever the system, and on the running example, orders 3
and 4 double the nodes for no better bound (see [Choosing a graph](@ref)).
Refinement builds the graph from the certificate instead: it solves, reads
where the certificate is tight, lifts the graph there, and solves again. An
outer loop searches over graphs, and on each graph [`certify`](@ref) computes
the best certificate.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = PCC.StabilityProblem(system)`, solved with Clarabel.

## In one call

[`refine`](@ref) starts from the one-node graph and runs the loop:

```@example running
trace = PCC.refine(PCC.QuadraticTemplate(), problem; optimizer = Clarabel.Optimizer)
PCC.rates(trace), PCC.n_nodes.(PCC.graphs(trace))
```

In two steps, the rate drops from about ``0.959`` to ``0.869`` with 3 nodes and
6 edges, where the De Bruijn hierarchy needs order 2, with 4 nodes and 8
edges, for the same bound. `refine(template, graph, problem)` starts from
your graph instead. Refinement runs on stability only.

## How a step works

A step reads the tight edges of the certificate, those whose edge inequality
is active (see [Reading a certificate](@ref)). Two results of
[ninite2026lifting](@cite) say where to lift:

- **Only the tight edges matter.** The tight edges alone give the same rate
  (Prop. 1): they hold the rate up, so the graph is lifted where they are.
- **A node with a single tight outgoing edge is not worth splitting.**
  Splitting it cannot lower the rate (Prop. 3); a node with two or more may.

The default algorithm, [`TightestNodeSplitting`](@ref), follows Algorithm 1
of [ninite2026lifting](@cite): it splits the node with the most tight
outgoing edges into one copy per outgoing edge, with [`OutSplitLift`](@ref),
and solves again. From the one-node graph, the first step gives the dual De
Bruijn graph of order 1. When no node has two tight outgoing edges, the rate
is the joint spectral radius (Thm. 4), and the run stops.

Every step is a lift that needs nothing from the template (see [Lifts](@ref)),
so the rate never increases, up to the bisection tolerance, and the lifted
graph is path-complete without a new check.

## Another algorithm

`refine` takes an `algorithm` keyword. [`BestOfTightEdgeLifts`](@ref) follows
Example 2 of [athanasopoulos2019polyhedral](@cite): it applies each split and
each product at every tight edge, solves every candidate graph, and keeps the
one with the lowest rate. A step costs one solve per candidate.

## When it stops

[`status`](@ref)`(trace)` says why the run stopped:

| Status | The run stopped because |
| :-- | :-- |
| [`OPTIMAL`](@ref) | the rate is proved equal to the joint spectral radius |
| [`STALLED`](@ref) | `stall_max` steps in a row did not lower the rate by `rtol` |
| [`DEPTH_REACHED`](@ref) | `depth_max` graphs were visited |
| [`STOPPED`](@ref) | the `stop` predicate held, for example `c -> c.rate < 1` |
| [`EXHAUSTED`](@ref) | the algorithm found no next graph |

```@example running
PCC.status(trace)
```

## The trace

The [`RefinementTrace`](@ref) keeps every step: [`certificates`](@ref),
[`graphs`](@ref), [`rates`](@ref), and [`steps`](@ref), each step a
[`Lifted`](@ref) graph with the [`origins`](@ref) of its nodes.

!!! note "Tolerances"
    Three tolerances drive the run: `rtol`, the bisection tolerance of each
    solve; `atol`, below which a slack counts as tight, at least `10 rtol`;
    and `gap_tol`, the gap between the rate and its lower bound at which the
    run stops.
