```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement: designing the graph

Every other part of this package takes a graph you chose and solves on it.
[`refine`](@ref) does the opposite: it starts from a graph you do not care about
and grows the one the system needs, guided by where the certificate is under
strain ([ninite2026lifting](@cite)).

This page explains the whole loop. [Refinement: letting the graph design itself](@ref)
runs it.

## What a graph buys, and what it costs

A path-complete graph `G` carrying a quadratic function at each node gives an
**upper** bound on the joint spectral radius. The bound is the optimum of

```
minimise   γ
subject to γ² P_a ⪰ Aᵢᵀ P_b Aᵢ     for every edge (a, b, i) of G
           P_a ≻ 0                  for every node a
```

written ``γ^*(G)``, and computed by [`jsr_bound`](@ref), which bisects on ``γ``
because the problem is convex only once ``γ`` is fixed.

More nodes give a tighter bound and cost more: `n` nodes means `n` matrix
variables and one matrix inequality per edge. So the question is not "which
graph is best" but **"where should the next node go?"**

[`de_bruijn`](@ref) answers it by brute force — remember the last `k` modes, at
`mᵏ` nodes. Refinement answers it by looking at the solution.

## The loop

At each step:

1. **Solve.** [`jsr_bound`](@ref) returns a certificate: the rate and one matrix
   `P_a` per node.
2. **Read the strain.** An edge `(a, b, i)` is **tight** when its inequality is
   active, ``λ_{min}(γ^2 P_a - A_i^\top P_b A_i) = 0``. Those edges hold the
   bound up; the rest have slack. [`edge_slacks`](@ref) measures them,
   [`tight_edges`](@ref) names them, [`tight_subgraph`](@ref) keeps only them.
3. **Find the bottleneck.** A node with **two or more** tight outgoing edges is
   being asked to serve two futures with one function. That is the node to split.
4. **Split it.** A *lift* replaces that node with several copies, each keeping
   part of its outgoing edges; every edge that entered the node now enters every
   copy.
5. **Repeat** on the bigger graph.

Step 4 can never make the bound worse: give every copy the function the original
node had and the old certificate is still feasible, so the rate can only fall or
stay. That is why the sequence of rates is monotone, and it needs nothing from
the template — which is why the forward lifts are sound for all of them.

## The lift

[`ForwardEdgeLift`](@ref) splits a node into one copy per outgoing **edge**.

Ninite & Jungers split per distinct **successor**. That grain cannot separate two
edges to the same successor, so a node held at exactly those stays held however
often it is lifted, and the optimality certificate below — which counts tight
outgoing *edges* — is unreachable for it. Measured over seven seed and system
combinations it never gives a better bound at equal node count, and on the
memoryless graph it cannot take a single step.

With one grain a copy simply **is** an outgoing edge, so the rule below counts
edges rather than asking what a given lift can tell apart.

## Choosing among bottlenecks

Several nodes may qualify. The rule is:

1. prefer the node with the **most** tight outgoing edges;
2. break ties by the **cheapest** split — fewest outgoing edges, since the lift
   adds one node per edge — node count being the budget;
3. break what remains by lowest node number.

No randomness, so a run is identical on every machine and Julia version. Pass an
`rng` to randomise step 3 instead — but seeding one does *not* make a run
reproducible across Julia versions, since `rand(rng, ::Vector)` may sample
differently between them.

## Knowing when to stop

[`status`](@ref) on the returned [`RefinementTrace`](@ref) says which of five
things happened.

| | |
| :-- | :-- |
| [`OPTIMAL`](@ref) | the rate **is** the joint spectral radius |
| [`STALLED`](@ref) | `stall_max` lifts in a row bought nothing |
| [`DEPTH_EXHAUSTED`](@ref) | `depth_max` reached with the bound still falling |
| [`STABLE`](@ref) | `until_stability` was set and the rate fell below 1 |

## Two certificates of optimality

The rate is an upper bound. To know it is *the* answer you must meet it from
below, and there are two independent ways.

### Structural — Theorem 4

> If every node has at most one outgoing edge in the tight subgraph, then
> ``γ^*(G) = ρ(\mathcal{A})``.

That is [`is_jsr_exact`](@ref), and it is a striking result: a purely
combinatorial property of *which constraints are active* proves the bound exact.

Two caveats, both load-bearing:

- **Sufficient, not necessary.** `false` means *unknown*, never *inexact*.
- **It depends on reading tightness correctly**, and tightness is an exact zero
  that a bisected solution never reaches.

### Numerical — the cycle bracket

A cycle ``(a_1,a_2,i_1) \dots (a_k,a_1,i_k)`` forces

```math
γ \ge ρ(A_{i_k} \cdots A_{i_1})^{1/k},
```

and any product of modes bounds the joint spectral radius from below. So
[`simple_cycles`](@ref) over the tight subgraph gives [`jsr_lower_bound`](@ref),
and rate minus bound is a **certified interval**. When it closes the answer is
proved — and this route does **not depend on the tightness tolerance at all**,
because a cycle of the tight subgraph is still a cycle of the graph. The
tolerance only decides where to look for good cycles.

[`lower_bounds`](@ref) gives the bracket at every step.

### Why both, and why the bracket is checked every step

Take two opposite rotations scaled by `0.9`. Their joint spectral radius is
exactly `0.9` and ``P = I`` attains it on *any* graph — so **every** edge is
tight. No node has at most one tight outgoing edge, Theorem 4 cannot fire, and
the loop would split forever at a constant bound: measured, 2 → 3 → 5 → 7 → 10
nodes over five identical rates.

The bracket closes on that instance at the **first** step, because the tight
subgraph contains a cycle whose spectral radius is exactly the rate.

That is why the bracket is computed every step rather than only once the search
dries up. The two conditions catch different cases, and the case Theorem 4 misses
is not exotic — it is what happens whenever the graph is *already* right. The
cost is under 1% of the solve it rides along with.

## The tolerances

| | |
| :-- | :-- |
| `rtol` | bisection tolerance of each [`jsr_bound`](@ref) call |
| `atol` | how close to zero counts as tight |
| `gap_tol` | how close the bracket must come to count as closed |
| `atol_max` | ceiling for escalating `atol`; off by default |

`atol` is the delicate one. Bisection stops just *above* the optimum, so an
active edge does not measure zero — it measures about the bisection gap. At
`rtol = 1e-6` the active edges of a worked example measure `1.3e-7`, `6.0e-7` and
`2.9e-6`, against `0.17` for the slack one: five orders of magnitude of room, but
only if `atol` sits between them.

Set it too low and active edges vanish. That is not merely conservative — with
the tight subgraph **empty**, every node satisfies Theorem 4 vacuously and the run
certifies a bound that is not the joint spectral radius. [`refine`](@ref)
therefore enforces `atol ≥ 10 rtol`, a decade being the least that separates an
active edge from a slack one.

`atol_max` is the remaining safeguard. Set it above `atol` and a dead end is no
longer taken at face value: the tolerance is multiplied by ten, up to the ceiling,
and the same certificate re-read. Nothing is re-solved and nothing restarted — a
tolerance decides how a solution is *read*, not what it is. With the decade
enforced this should rarely be needed; it guards a solution whose accuracy is
worse than `rtol` suggests.

## Where this differs from the paper

Worth knowing if you are reading both.

| | paper | here |
| :-- | :-- | :-- |
| lift | node-grained | edge-grained, the coarse grain being dominated — which makes the split rule and Theorem 4 literally the same test |
| cycle bound | computed once the structural condition fires | checked every step, the only way the all-edges-tight case is ever certified |
| tolerance escalation | restart the algorithm | re-read the same certificate; no solve repeated |
| tie-breaking | unspecified | cheapest split, deterministic |

The first row is why the search drying up *is* the certificate here: with copies
and edges the same thing, "no node holds two tight outgoing edges" is exactly
Theorem 4's hypothesis, so there is no outcome for *exhausted but unproved*.

```@docs; canonical=false
refine
```
