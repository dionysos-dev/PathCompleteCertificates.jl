```@meta
CurrentModule = PathCompleteCertificates
```

# Graph improvement via refinements

Every other part of this package takes a graph you chose and solves on it.
[`refine`](@ref) does the opposite: it starts from a graph you do not care
about and grows the one the system needs, guided by where the certificate is
under strain ([ninite2026lifting](@cite)).
[Refinement: letting the graph design itself](@ref) runs it.

A **refinement** is a transformation of a path-complete graph that is no worse
for every template: a copy inherits its origin's function, a product chains
two edge inequalities. The literature calls these lifts too; here the word
*lift* is kept for the [lifts that compare graphs](@ref "Graph comparison via lifts"),
and the transformations that improve one are refinements.

## The four atoms

Every refining construction in the literature is one of two local operations
at an edge ``(s, d, w)``, forward or backward
([athanasopoulos2019polyhedral](@cite), Defs. 4 to 7).

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

- `ForwardEdgeSplit` on `outgoing_edges(graph, s)` is the forward lift at a
  node of [ninite2026lifting](@cite), Def. 3, the default step of the loop;
- `BackwardEdgeSplit` on `edges(graph)` is the path-dependent lift of
  [philippe2016stability](@cite), Def. 3, [`PathDependentRefinement`](@ref)`(1)`;
  iterated from the one-node graph it is [`de_bruijn`](@ref);
- either product on `edges(graph)` is [`ProductRefinement`](@ref)`(2)`, the
  product lift of [philippe2016stability](@cite), Def. 2.

None of this needs anything from the template: give every copy the function of
the node it came from and the old certificate is still feasible
([ninite2026lifting](@cite), Thm. 3); two chained edge inequalities imply the
product's ([athanasopoulos2019polyhedral](@cite), Thm. 1). The one step that is
not an atom is a lift, [`CompositionLift`](@ref), which can strictly improve a
graph for templates closed under composition ([jongeneel2025ordering](@cite),
Ex. IV.4) and which [`Hierarchy`](@ref) accepts where it is valid.

## The loop

A path-complete graph with a quadratic function at each node gives an upper
bound ``γ^*(G)`` on the joint spectral radius, the optimum of ``\min γ``
subject to ``γ^2 P_a \succeq A_i^\top P_b A_i`` on every edge ``(a, b, i)``
and ``P_a \succ 0``; [`jsr_bound`](@ref) bisects on ``γ``. More nodes give a
tighter bound and cost more, so the question is **where the next node should
go**. [`de_bruijn`](@ref) answers by brute force, remembering the last `k`
modes at `mᵏ` nodes. Refinement answers by looking at the solution. At each
step:

1. **Solve.** [`jsr_bound`](@ref) returns a certificate: the rate and one
   function per node.
2. **Read the strain.** An edge is **tight** when its inequality is active.
   [`edge_slacks`](@ref) measures them, [`tight_edges`](@ref) names them,
   [`tight_subgraph`](@ref) keeps only them ([ninite2026lifting](@cite),
   Def. 4).
3. **Propose.** A *strategy* reads the certificate and proposes refined
   graphs.
4. **Refine.** With `select = :first` the first proposal is taken; with
   `select = :best` every proposal is solved and the lowest rate kept.
5. **Repeat** on the bigger graph.

A refinement never makes the bound worse, so the sequence of rates is
monotone.

### Strategies

A strategy is any callable `(certificate; atol) -> Vector{Refined}`. The
package ships the three rules of the literature.

| Strategy | Proposes | Source |
| :-- | :-- | :-- |
| [`SplitTightNode`](@ref), the default | one candidate: [`ForwardEdgeSplit`](@ref) on the out-star of the node held at the most tight outgoing edges; ties go to the cheapest split, then the lowest node | [ninite2026lifting](@cite), Def. 3 |
| [`RefineTightEdges`](@ref) | every atom at every tight edge; with `select = :best` the one with the smallest rate is kept | [athanasopoulos2019polyhedral](@cite), Example 2 |
| [`Hierarchy`](@ref)`(step)` | one candidate: a global refinement, a local one at every edge, or a lift | [philippe2016stability](@cite); [jongeneel2025ordering](@cite), §IV-A |

`Hierarchy(PathDependentRefinement(1))` from the one-node graph walks the De
Bruijn hierarchy one order per step, which makes [`de_bruijn`](@ref) a special
case of the loop and a baseline inside it.

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
| [`STALLED`](@ref) | `stall_max` steps in a row bought nothing |
| [`DEPTH_REACHED`](@ref) | `depth_max` reached with the bound still falling |
| [`STOPPED`](@ref) | the `stop` predicate held, `c -> c.rate < 1` being the usual one |
| [`EXHAUSTED`](@ref) | the strategy proposed nothing, and the gap had not closed |

Only the first is a certified answer. The trace keeps every certificate and
every [`Refined`](@ref) step, so a run can be read back: [`rates`](@ref),
[`graphs`](@ref), [`steps`](@ref) and the [`origins`](@ref) of each node.

## Two certificates of optimality

The rate is an upper bound. To know it is *the* answer you must meet it from
below, and there are two independent ways, both checked at every step.

**Structural.** If every node has at most one outgoing edge in the tight
subgraph, then ``γ^*(G) = ρ(\mathcal{A})`` ([ninite2026lifting](@cite),
Thm. 4). That is [`is_jsr_exact`](@ref): a combinatorial property of which
constraints are active proves the bound exact. It is sufficient, not
necessary, so `false` means *unknown*; and it depends on reading tightness
correctly.

**Numerical.** A cycle ``(a_1,a_2,i_1) \dots (a_k,a_1,i_k)`` of the tight
subgraph forces ``γ \ge ρ(A_{i_k} \cdots A_{i_1})^{1/k}``, and any product of
modes bounds the joint spectral radius from below. [`jsr_lower_bound`](@ref)
takes the best cycle, and rate minus bound is a certified interval that does
not depend on the tightness tolerance at all, since a cycle of the tight
subgraph is still a cycle of the graph.

The two catch different cases. Two opposite rotations scaled by `0.9` have
``P = I`` exact on any graph, so every edge is tight, Theorem 4 can never
fire, and the loop would split forever at a constant bound; the bracket closes
at the first step. Whenever the graph is *already* right, only the bracket
sees it.

## The tolerances

| | |
| :-- | :-- |
| `rtol` | bisection tolerance of each [`jsr_bound`](@ref) call |
| `atol` | how close to zero counts as tight |
| `gap_tol` | how close the bracket must come to count as closed |

`atol` is the delicate one. Bisection stops just *above* the optimum, so an
active edge does not measure zero: it measures about the bisection gap. At
`rtol = 1e-6` the active edges of a worked example measure `1.3e-7`, `6.0e-7`
and `2.9e-6`, against `0.17` for the slack one. Set `atol` too low and the
tight subgraph comes out empty, every node satisfies Theorem 4 vacuously, and
the run certifies a bound that is not the joint spectral radius.
[`refine`](@ref) therefore enforces `atol ≥ 10 rtol`.

## Generic in the problem

The loop names no problem. It reads [`best_certificate`](@ref) to solve a
step, [`objective`](@ref) to compare two steps and [`optimality_gap`](@ref) to
stop; a problem that answers the three joins the loop with the strategies and
the trace unchanged. Stability answers them today, and
[What works with what](@ref) says which templates it runs on.

```@docs; canonical=false
refine
```
