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

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = PCC.StabilityProblem(system)`, solved with Clarabel.

## In one call

[`refine`](@ref) starts from the one-node graph, solves, and lifts the graph
where the certificate is tight, until the bound is proved exact or a limit is
reached:

```@example running
trace = PCC.refine(PCC.QuadraticTemplate(), problem; optimizer = Clarabel.Optimizer)
PCC.rates(trace), PCC.n_nodes.(PCC.graphs(trace))
```

`refine(template, graph, problem)` starts from your graph instead. Refinement
runs on stability only.

## The algorithms

`refine` takes an `algorithm` keyword.

### TightestNodeSplitting

The default, based on Algorithm 1 of [ninite2026lifting](@cite): at each step,
split the node with the most tight outgoing edges into one copy per outgoing
edge ([`OutSplitLift`](@ref)). From the one-node graph, the first step gives
the dual De Bruijn graph of order 1.

### BestOfTightEdgeLifts

The procedure of Example 2 of [athanasopoulos2019polyhedral](@cite): apply each
split and each product at every tight edge, solve every candidate graph, and
keep the one with the lowest rate. A step costs one solve per candidate.

## Why the bound never gets worse

Every step is a lift that needs nothing from the template, so a certificate on
a graph gives one on the next graph, at the same rate. Up to the bisection
tolerance, the rate never increases.

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

Three tolerances drive the run: `rtol`, the bisection tolerance of each solve;
`atol`, below which a slack counts as tight, at least `10 rtol`; and `gap_tol`,
the gap between the rate and its lower bound at which the run stops.
