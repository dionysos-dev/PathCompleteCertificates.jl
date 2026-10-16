```@meta
CurrentModule = PathCompleteCertificates
```

# Graph refinement

[`refine`](@ref) is an algorithm that applies [lifts](@ref "Lifts"): it solves
a certificate, reads where it is tight, applies a lift there, and solves
again. A lift never makes the certificate worse, so the bound can only improve.
[Refinement: splitting nodes at tight edges](@ref) runs it.

Refinement is a stability tool, and runs on stability only: each algorithm
below comes from a paper on the joint spectral radius, the bound is an upper
bound on it, and it can be proved exact.

## The loop

A path-complete graph with a quadratic function at each node gives an upper
bound ``γ^*(G)`` on the joint spectral radius, the optimum of ``\min γ``
subject to ``γ^2 P_a \succeq A_i^\top P_b A_i`` on every edge ``(a, b, i)``
and ``P_a \succ 0``; [`jsr_bound`](@ref) bisects on ``γ``. A lifted graph
gives a bound at least as good, with a larger program. [`de_bruijn`](@ref)
adds nodes everywhere, remembering the last `k` modes at `mᵏ` nodes;
[`refine`](@ref) adds them where the solution is tight. At each step:

1. **Solve.** [`jsr_bound`](@ref) returns a certificate: the rate and one
   function per node.
2. **Find the tight edges.** An edge is **tight** when its inequality is active.
   [`edge_slacks`](@ref) measures them, [`tight_edges`](@ref) names them,
   [`tight_subgraph`](@ref) keeps only them ([ninite2026lifting](@cite),
   Def. 4).
3. **Lift.** [`next_graph`](@ref) of the `algorithm` reads the certificate
   and returns the next graph, a lift of the current one.
4. **Repeat** on the lifted graph.

## The algorithms

| Algorithm | At each step | Starts from | Source |
| :-- | :-- | :-- | :-- |
| [`TightestNodeSplitting`](@ref), the default | the out-splitting of the node with the most tight outgoing edges, at least two | the one-node graph | [ninite2026lifting](@cite), Algorithm 1 |
| [`BestOfTightEdgeLifts`](@ref) | the four splits and products at every tight edge, each solved, the lowest rate kept | the one-node graph | [athanasopoulos2019polyhedral](@cite), Example 2 |

**[`TightestNodeSplitting`](@ref)** follows Algorithm 1 of [ninite2026lifting](@cite).
Its step is the out-splitting of a node, one copy per outgoing edge; from the
one-node graph the first step gives the dual De Bruijn graph of order 1. Ties
go to the node with the fewest outgoing edges, then the lowest index, so a run
is deterministic; `rng` breaks them at random instead.

**[`BestOfTightEdgeLifts`](@ref)** follows Example 2 of
[athanasopoulos2019polyhedral](@cite): its partial P\*-, P-, T- and T\*-lifts
at every tight edge, one edge at a time, each candidate solved and the lowest
rate kept, so a step costs one solve per candidate. The products write words on
the edges, so the graph gains edges rather than nodes.

A new algorithm is a subtype of [`AbstractRefinementAlgorithm`](@ref) that
implements [`next_graph`](@ref), and [`initial_graph`](@ref) when it starts
elsewhere than the one-node graph.

### Where it starts

`refine(template, problem)` starts from [`initial_graph`](@ref) of the
algorithm. `refine(template, graph, problem)` starts from a graph of yours.
Path-completeness is checked on that first graph only; every lift preserves
it.

### When it stops

[`status`](@ref) on the returned [`RefinementTrace`](@ref) says which of five
things happened.

| | |
| :-- | :-- |
| [`OPTIMAL`](@ref) | the rate **is** the joint spectral radius |
| [`STALLED`](@ref) | `stall_max` steps in a row did not improve the objective by `rtol` |
| [`DEPTH_REACHED`](@ref) | `depth_max` reached with the bound still falling |
| [`STOPPED`](@ref) | the `stop` predicate returned `true`, for example `c -> c.rate < 1` |
| [`EXHAUSTED`](@ref) | the algorithm had no next graph, and the gap had not closed |

Only `OPTIMAL` proves the rate equal to the joint spectral radius. The trace
keeps every certificate and every [`Lifted`](@ref) step, so a run can be read
back: [`rates`](@ref), [`graphs`](@ref), [`steps`](@ref) and the
[`origins`](@ref) of each node.

## Two certificates of optimality

The rate is an upper bound on the joint spectral radius. Two independent
tests, run at every step, can prove it equal.

**Structural.** If every node has at most one outgoing edge in the tight
subgraph, then ``γ^*(G) = ρ(\mathcal{A})`` ([ninite2026lifting](@cite),
Thm. 4). [`is_jsr_exact`](@ref) tests this condition. It is sufficient, not
necessary, so `false` means *unknown*, and its answer depends on the tightness
tolerance.

**Numerical.** A cycle ``(a_1,a_2,i_1) \dots (a_k,a_1,i_k)`` of the tight
subgraph forces ``γ \ge ρ(A_{i_k} \cdots A_{i_1})^{1/k}``, and any product of
modes bounds the joint spectral radius from below. [`jsr_lower_bound`](@ref)
returns the largest such bound over the cycles of the tight subgraph. The
interval between it and the rate contains the joint spectral radius whatever
the tolerance, since a cycle of the tight subgraph is a cycle of the graph.

The two tests apply in different cases. For two opposite rotations scaled by
`0.9`, ``P = I`` is optimal on any graph and every edge is tight, so Theorem 4
never applies and the loop would split indefinitely at a constant bound; the
lower bound equals the rate at the first step.

## The tolerances

| | |
| :-- | :-- |
| `rtol` | bisection tolerance of each [`jsr_bound`](@ref) call |
| `atol` | how close to zero counts as tight |
| `gap_tol` | the gap between the rate and the lower bound at which the run stops |

Bisection stops *above* the optimum, so the slack of an active edge is of the
order of the bisection gap, not zero. With `atol` too small the tight subgraph
is empty and the loop learns nothing: there is no node to split, no cycle to
bound the rate from below, and [`is_jsr_exact`](@ref) answers `false`, since
at the optimum the tight subgraph contains a cycle
([ninite2026lifting](@cite), Prop. 1). [`refine`](@ref) therefore requires
`atol ≥ 10 rtol`. Every function reading tight edges shares the default
`atol = 1e-4`; read a certificate from [`jsr_bound`](@ref) with an `atol` at
least ten times the `rtol` it was computed to.

## Other problems

[`refine`](@ref) reads [`best_certificate`](@ref), [`objective`](@ref),
[`edge_slacks`](@ref) and [`optimality_gap`](@ref) of a certificate; only
stability defines them all, and the literature refines graphs for stability
only. On any other problem [`refine`](@ref) throws.
[What works with what](@ref) says which templates the loop runs on.

```@docs; canonical=false
refine
```
