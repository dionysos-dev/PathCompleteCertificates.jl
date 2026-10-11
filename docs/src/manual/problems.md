```@meta
CurrentModule = PathCompleteCertificates
```

# Problems

A problem specifies the meaning of an edge: the inequality that the node
functions at its two ends must satisfy. The template defines the search space
for these functions; the problem defines the constraints the graph imposes on
them, and hence the property the certificate establishes.

| Problem | Edge inequality on ``(s, d, i)`` | Entry points |
| :-- | :-- | :-- |
| [`StabilityProblem`](@ref) | ``V_d(A_i x) \le \gamma^{d}\, V_s(x)`` | [`certify`](@ref), [`jsr_bound`](@ref) |
| [`SafetyProblem`](@ref) | ``B_d(A_i x) \le B_s(x)``, plus the separation of the two sets | [`certify`](@ref) |
| [`OptimalControlProblem`](@ref) | ``x^\top Q x + u^\top R u + V_d(A_i x + B_i u) \le V_s(x)`` | [`certify`](@ref) |

## Stability

A switched linear system is stable under arbitrary switching exactly when the
joint spectral radius of its mode matrices is smaller than one, and
path-complete Lyapunov functions give certified upper bounds on it
([ahmadi2014joint](@cite), Thm. 2.4). Given a candidate bound ``\gamma``, a
certificate at rate ``\gamma`` proves the system scaled by ``1/\gamma``
stable:

- [`certify`](@ref)`(template, graph, problem; rate)` attempts to certify one
  candidate bound, and [`is_feasible`](@ref) of the result says whether it
  did;
- [`jsr_bound`](@ref) bisects on the rate and returns the certificate at the
  smallest rate found, to the tolerance `rtol`.

The edge inequality scales as ``\gamma^d`` with ``d`` the template's
[`homogeneity_degree`](@ref), so that ``\gamma`` is a per-step bound whatever
the template, and as ``\gamma^{dk}`` on an edge reading a word of ``k`` modes.

```@docs; canonical=false
jsr_bound
```

!!! warning "A bound is always an *upper* bound"
    An infeasible result means that no certificate was found **in this
    template on this graph**, not that the system is unstable. Try another
    template, or another graph.

## Safety

The safety problem is to prove that every trajectory starting in a given
initial set never reaches a given unsafe set, under arbitrary switching.
Following [anand2024barrier](@cite), it is certified by path-complete barrier
functions: one function per node, negative on the initial set, positive on the
unsafe set, and non-increasing along every edge, so that the region they cut
out is invariant, contains the initial set and avoids the unsafe one.

Safety is implemented for the quadratic template, the barriers being
``[x; 1]^\top P_s [x; 1]``, and [`SafetyProblem`](@ref) takes the two sets in
the same homogeneous coordinates, as ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``.

!!! note "What `margin` is"
    The edge inequality is non-strict; a strict one would collapse around any
    cycle, and every path-complete graph has one. The strictness sits on the
    separation of the sets instead, and `certificate.margin` is how much of it
    the solver achieved. Zero means the sets are not separated.

## Optimal control

For a system with an input, the problem of [ninite2026path](@cite): the mode
is chosen adversarially, the input by a state feedback ``u = K_s x`` at each
node, and the node functions bound the cost ``\sum_k x_k^\top Q x_k + u_k^\top R u_k``
from above. [`certify`](@ref) returns the gains and the bound. The problem is
tied to the quadratic template, since its inequality is convex only after the
substitution ``S = P^{-1}``, ``Y = KS``, and it needs a **complete** graph.

```@docs; canonical=false
certify
```

!!! danger "`objective` is not the bound"
    It is a volume heuristic for choosing among feasible certificates, and is
    routinely negative. The bound is `certificate(x)`.

## Reading a certificate

Every entry point returns a certificate object, feasible or not, so that "no
certificate exists here" can be told from "the solver gave up". Read it in
this order:

| | |
| :-- | :-- |
| [`is_feasible`](@ref)`(c)` | was anything certified at all? Check this first |
| [`status`](@ref)`(c)` | the solver's termination status, when it was not |
| `c.rate`, `c.margin`, `c.gains` | what the problem certifies, a typed field of its own certificate |
| [`functions`](@ref)`(c)` | the fitted node functions, one per node, each callable |
| `c(x)` | the [`common`](@ref) function, what graph and template certify together |

A stability certificate says more than its rate, and the graph layer is built
on what it says:

| | |
| :-- | :-- |
| [`edge_slacks`](@ref) | how far each edge inequality is from being active |
| [`tight_edges`](@ref), [`tight_subgraph`](@ref) | the edges that hold the bound up ([ninite2026lifting](@cite), Def. 4) |
| [`is_jsr_exact`](@ref) | the rate **is** the joint spectral radius when every node has at most one tight outgoing edge ([ninite2026lifting](@cite), Thm. 4) |
| [`jsr_lower_bound`](@ref) | the bound from below given by the cycles of the tight subgraph, bracketing the rate |
| [`dual`](@ref)`(c)` | the same certificate on the dual graph, for the transposed system, in the dual template ([debauche2024thesis](@cite), Lemma 6.25) |

Tightness is read against a tolerance, since a bisected solution never reaches
an exact zero; [Graph improvement via refinements](@ref) explains how to set
it, and how the loop uses these readings.
