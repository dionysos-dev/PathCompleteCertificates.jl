```@meta
CurrentModule = PathCompleteCertificates
```

# Graph improvement via refinements

[`refine`](@ref) starts from a small graph, adds nodes where the certificate
is tight, and solves again ([ninite2026lifting](@cite)).
[Refinement: splitting nodes at tight edges](@ref) runs it.

A **refinement** is a transformation of a path-complete graph that is no worse
for every template: a copy inherits its origin's function, a product chains
two edge inequalities. The literature calls these lifts too; here the word
*lift* is kept for the [lifts that compare graphs](@ref "Graph comparison via lifts"),
and the transformations that improve one are refinements.

## The four atoms

The **atoms** are two local operations at an edge ``(s, d, w)``, a split and a
product, each forward or backward ([athanasopoulos2019polyhedral](@cite),
Defs. 4 to 7). The refining constructions of the literature are built from
them.

| Refinement | At one edge `(s, d, w)` | Paper's name |
| :-- | :-- | :-- |
| [`ForwardEdgeSplit`](@ref) | a copy of `s` owning that outgoing edge and every incoming one | partial P\*-lift, Def. 7 |
| [`BackwardEdgeSplit`](@ref) | a copy of `d` owning that incoming edge and every outgoing one | partial P-lift, Def. 6 |
| [`ForwardEdgeProduct`](@ref) | replace it by `(s, d′, w·u)` for every `(d, d′, u)` | partial T-lift, Def. 4 |
| [`BackwardEdgeProduct`](@ref) | replace it by `(s′, d, u·w)` for every `(s′, s, u)` | partial T\*-lift, Def. 5 |

Drawn at the edge `s ─w─▶ d` of a graph where `s` also reads `u` to `f` and
is entered by `a`, and `d` is also entered by `b` and leaves for `e`:

```
      before                      ForwardEdgeSplit               BackwardEdgeSplit

 a ──v──▶ s ──w──▶ d ──x──▶ e     a ──v──▶ s′ ──w──▶ d ──x──▶ e   a ──v──▶ s ──w──▶ d′ ──x──▶ e
          │        ▲              │                  ▲                     │
          u        t              v                  t                     u    b ──t──▶ d ──x──▶ e
          ▼        │              ▼                  │                     ▼
          f        b              s ──u──▶ f         b                     f

      ForwardEdgeProduct                              BackwardEdgeProduct

 a ──v──▶ s ──w·x──▶ e                                a ──v·w──▶ d ──x──▶ e
          │                                           │          ▲
          u          b ──t──▶ d ──x──▶ e              v          t
          ▼                                           ▼          │
          f                                           s ──u──▶ f b
```

A split adds a node and splits the inequalities that passed through it. A
product adds no node and writes a **word** on an edge: one inequality on
``A_x A_w`` with nothing imposed on the state in between, which is sound for
stability only. A [`WordGraph`](@ref) carries words, and its
[`expanded_form`](@ref) reads the same language with one mode per edge; for a
template closed under composition the two certify the same rate, the word
graph with fewer variables ([debauche2024thesis](@cite), Prop. 7.70).

Each backward atom is the [`dual`](@ref) of the forward one, and the classical
hierarchies are the atoms at every edge:

- `ForwardEdgeSplit` on `outgoing_edges(graph, s)`, the default step of the
  loop, gives `s` one copy per outgoing edge: the forward lift at a node of
  [ninite2026lifting](@cite), Def. 3, whenever no two edges of `s` share a
  destination, which gives one copy per successor;
- `BackwardEdgeSplit` on `edges(graph)` is the path-dependent lift of
  [philippe2016stability](@cite), Def. 3, [`PathDependentRefinement`](@ref)`(1)`;
  iterated from the one-node graph it is [`de_bruijn`](@ref);
- either product on `edges(graph)` is [`ProductRefinement`](@ref)`(2)`, the
  product lift of [philippe2016stability](@cite), Def. 2.

The atoms are valid for every template: giving every copy the function of the
node it came from keeps the old certificate feasible
([ninite2026lifting](@cite), Thm. 3), and two chained edge inequalities imply the
product's ([athanasopoulos2019polyhedral](@cite), Thm. 1). The one step that is
not an atom is a lift, [`CompositionLift`](@ref), which can strictly improve a
graph for templates closed under composition ([jongeneel2025ordering](@cite),
Ex. IV.4) and which [`Hierarchy`](@ref) accepts where it is valid.

## The loop

A path-complete graph with a quadratic function at each node gives an upper
bound ``γ^*(G)`` on the joint spectral radius, the optimum of ``\min γ``
subject to ``γ^2 P_a \succeq A_i^\top P_b A_i`` on every edge ``(a, b, i)``
and ``P_a \succ 0``; [`jsr_bound`](@ref) bisects on ``γ``. A refined graph
gives a bound at least as good, with a larger program. [`de_bruijn`](@ref)
adds nodes everywhere, remembering the last `k` modes at `mᵏ` nodes;
[`refine`](@ref) adds them where the solution is tight. At each step:

1. **Solve.** [`jsr_bound`](@ref) returns a certificate: the rate and one
   function per node.
2. **Find the tight edges.** An edge is **tight** when its inequality is active.
   [`edge_slacks`](@ref) measures them, [`tight_edges`](@ref) names them,
   [`tight_subgraph`](@ref) keeps only them ([ninite2026lifting](@cite),
   Def. 4).
3. **Propose.** A *strategy* reads the certificate and proposes refined
   graphs.
4. **Refine.** With `select = :first` the first proposal is taken; with
   `select = :best` every proposal is solved and the lowest rate kept.
5. **Repeat** on the refined graph.

A refinement never makes the bound worse, so the sequence of rates is
monotone.

### Strategies

A strategy is any callable `(certificate; atol) -> Vector{Refined}`. The
package provides three, from the literature.

| Strategy | Proposes | Source |
| :-- | :-- | :-- |
| [`SplitTightNode`](@ref), the default | one candidate: [`ForwardEdgeSplit`](@ref) on the out-star of the node with the most tight outgoing edges; ties go to the node with fewest outgoing edges, then the lowest index | [ninite2026lifting](@cite), Def. 3 |
| [`RefineTightEdges`](@ref) | every atom at every tight edge; with `select = :best` the one with the smallest rate is kept | [athanasopoulos2019polyhedral](@cite), Example 2 |
| [`Hierarchy`](@ref)`(step)` | one candidate: a global refinement, a local one at every edge, or a lift | [philippe2016stability](@cite); [jongeneel2025ordering](@cite), §IV-A |

`Hierarchy(PathDependentRefinement(1))` from the one-node graph goes up the De
Bruijn hierarchy one order per step, so the [`de_bruijn`](@ref) graphs are a
special case of the loop.

### Where it starts

`refine(template, problem)` starts from [`common_graph`](@ref) of the system:
the common Lyapunov function graph, or the automaton under constrained
switching, so the loop reads the right language from the first step.
`refine(template, graph, problem)` starts from a graph of yours.
Path-completeness is checked on that first graph only; every refinement
preserves it.

### When it stops

[`status`](@ref) on the returned [`RefinementTrace`](@ref) says which of five
things happened.

| | |
| :-- | :-- |
| [`OPTIMAL`](@ref) | the rate **is** the joint spectral radius |
| [`STALLED`](@ref) | `stall_max` steps in a row did not improve the objective by `rtol` |
| [`DEPTH_REACHED`](@ref) | `depth_max` reached with the bound still falling |
| [`STOPPED`](@ref) | the `stop` predicate returned `true`, for example `c -> c.rate < 1` |
| [`EXHAUSTED`](@ref) | the strategy proposed nothing, and the gap had not closed |

Only `OPTIMAL` proves the rate equal to the joint spectral radius. The trace keeps every certificate and
every [`Refined`](@ref) step, so a run can be read back: [`rates`](@ref),
[`graphs`](@ref), [`steps`](@ref) and the [`origins`](@ref) of each node.

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
is empty, every node satisfies the condition of Theorem 4 vacuously, and the
run reports as exact a bound that is not the joint spectral radius.
[`refine`](@ref) therefore requires `atol ≥ 10 rtol`.

## Other problems

[`refine`](@ref) runs on every problem that implements
[`best_certificate`](@ref), [`objective`](@ref), [`edge_slacks`](@ref) and
[`optimality_gap`](@ref); stability and safety do. Safety has no lower bound, so its runs end on a stall
or the depth budget rather than [`OPTIMAL`](@ref), with the margin read as
`c.margin` on each certificate of the trace.
[What works with what](@ref) says which templates the loop runs on.

```@docs; canonical=false
refine
```
