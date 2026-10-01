```@meta
CurrentModule = PathCompleteCertificates
```

# Problems

A problem says what the **edge inequality** is. The graph, the templates and the
aggregation are the same across all three.

| Problem | Edge inequality on ``(s, d, i)`` | Entry points |
| :-- | :-- | :-- |
| [`StabilityProblem`](@ref) | ``V_d(A_i x) \le \gamma^{d}\, V_s(x)`` | [`certify`](@ref), [`is_stable`](@ref), [`jsr_bound`](@ref) |
| [`SafetyProblem`](@ref) | ``B_d(A_i x) \le B_s(x)``, plus set separation | [`certify`](@ref) |
| [`OptimalControlProblem`](@ref) | ``x^\top Q x + u^\top R u + V_d(A_i x + B_i u) \le V_s(x)`` | [`certify`](@ref) |

## Stability

[ahmadi2014joint](@cite). [`certify`](@ref) solves once at a given rate;
[`is_stable`](@ref) asks only whether that rate is feasible, and
[`jsr_bound`](@ref) bisects for the best one. Every template works here. The
exponent ``d`` is the template's [`rate_exponent`](@ref), so ``\gamma`` means
the same contraction per step whichever template is in use, and an edge
reading a word of ``k`` modes scales as ``\gamma^{dk}``.

```@docs; canonical=false
jsr_bound
```

!!! warning "A bound is always an *upper* bound"
    `false` means no certificate was found **in this template on this graph**,
    not that the system is unstable. Try another template, or another graph.

## Safety

[anand2024barrier](@cite). A barrier is negative on the initial set, positive on
the unsafe set, and never increases along a transition, so the region it cuts
out is invariant, contains the initial set, and never reaches the unsafe one.

[`SafetyProblem`](@ref) takes both sets in **homogeneous coordinates**, as
``\{x : [x; 1]^\top S [x; 1] \ge 0\}``.

!!! note "What `margin` is"
    The edge inequality is non-strict. It must be, since a strict one collapses
    around any cycle, and every path-complete graph has one. The strictness
    sits on the set separation instead, and `certificate.margin` is how much
    of it the solver achieved.

## Optimal control

[ninite2026path](@cite), for a switched system **with an input**: the mode is
adversarial, the input is yours. Returns the bound and a state-feedback gain per
node.

```@docs; canonical=false
certify
```

Convex only after the substitution ``S = P^{-1}``, ``Y = KS``, which is specific
to the quadratic case, so this problem is tied to [`QuadraticTemplate`](@ref).
It also needs a **complete** graph, not merely a path-complete one.

!!! danger "`objective` is not the bound"
    It is a volume heuristic for choosing among feasible certificates, and is
    routinely negative. The bound is `certificate(x)`.

## Reading a certificate

| | |
| :-- | :-- |
| `is_feasible(c)` | was anything certified at all? |
| `status(c)` | the solver's termination status, when it was not |
| `functions(c)` | the fitted node functions, one per node, each callable |
| `c(x)` | the [`common`](@ref) function, what graph and template certify together |

What each problem specifically certifies is a field of its own:
`StabilityCertificate.rate`, `SafetyCertificate.margin`,
`OptimalControlCertificate.gains`.

!!! warning "Check `is_feasible` first"
    An infeasible result is still a certificate object. It carries the solver
    status, so you can tell "no certificate exists here" from "the solver gave
    up".

## Reading a stability certificate further

A stability certificate says more than its rate, and the graph layer is built
on what it says.

| | |
| :-- | :-- |
| [`edge_slacks`](@ref) | how far each edge inequality is from being active |
| [`tight_edges`](@ref), [`tight_subgraph`](@ref) | the edges that hold the bound up ([ninite2026lifting](@cite), Def. 4) |
| [`is_jsr_exact`](@ref) | the rate **is** the joint spectral radius when every node has at most one tight outgoing edge ([ninite2026lifting](@cite), Thm. 4) |
| [`jsr_lower_bound`](@ref) | the bound from below that the cycles of the tight subgraph give, bracketing the rate |
| [`dual`](@ref)`(certificate)` | the same certificate on the dual graph, for the transposed system, in the dual template ([debauche2024thesis](@cite), Lemma 6.25); see [Duality](@ref) |

Tightness is read against a tolerance, because a bisected solution never
reaches an exact zero; [Refinement: designing the graph](@ref) explains how to
set it.

## What a refinement loop reads

[`refine`](@ref) is generic in the problem. A problem joins it by answering
three questions: [`best_certificate`](@ref), the solve that drives one step;
[`objective`](@ref), the number to improve; and [`optimality_gap`](@ref), how
far that number is known to be from the best any graph could do. Stability
answers all three with [`jsr_bound`](@ref), the rate and the bracket above.
Safety and optimal control do not answer them yet, so today the loop runs for
stability.
