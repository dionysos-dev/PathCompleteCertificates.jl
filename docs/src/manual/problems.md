```@meta
CurrentModule = PathCompleteCertificates
```

# Problems

A problem specifies the inequality that the node functions at the two ends of
an edge must satisfy, and therefore the property a certificate proves.

| Problem | Edge inequality on ``(s, d, i)`` | Entry points |
| :-- | :-- | :-- |
| [`StabilityProblem`](@ref) | ``V_d(A_i x) \le \gamma^{p}\, V_s(x)`` | [`certify`](@ref), [`jsr_bound`](@ref) |
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

The edge inequality scales as ``\gamma^p`` with ``p`` the template's
[`homogeneity_degree`](@ref), so that ``\gamma`` is a per-step bound whatever
the template, and as ``\gamma^{pk}`` on an edge reading a word of ``k`` modes.

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
    The edge inequality is non-strict: at ``x = 0`` it reads
    ``B_d(0) \le B_s(0)``, so a strict version would fail around any cycle,
    and every path-complete graph has one. The strict inequality is imposed on
    the separation of the sets instead, and `certificate.margin` is its value
    in the solution. Zero means the sets are not separated.

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

## Reading a certificate

Every entry point returns a certificate, feasible or not, and its status tells
an infeasible problem from a solver failure. Read it in this order:

| | |
| :-- | :-- |
| [`is_feasible`](@ref)`(c)` | was anything certified at all? Check this first |
| [`status`](@ref)`(c)` | the solver's termination status, when it was not |
| `c.rate`, `c.margin`, `c.gains` | what the problem certifies |
| [`functions`](@ref)`(c)` | the fitted node functions, one per node, each callable |
| `c(x)` | the [`common`](@ref) function |

The following functions read further information from a certificate. The
first two rows apply to stability and safety certificates, the others to
stability certificates only:

| | |
| :-- | :-- |
| [`edge_slacks`](@ref) | how far each edge inequality is from being active |
| [`tight_edges`](@ref), [`tight_subgraph`](@ref) | the edges whose inequality is active ([ninite2026lifting](@cite), Def. 4) |
| [`is_jsr_exact`](@ref) | the rate **is** the joint spectral radius when every node has at most one tight outgoing edge ([ninite2026lifting](@cite), Thm. 4) |
| [`jsr_lower_bound`](@ref) | a lower bound on the joint spectral radius, from the cycles of the tight subgraph |
| [`dual`](@ref)`(c)` | the same certificate on the dual graph, for the transposed system, in the dual template ([debauche2024thesis](@cite), Lemma 6.25) |

Tightness is read against a tolerance, since a bisected solution never reaches
an exact zero; [Graph refinement](@ref) explains how to set
it, and how [`refine`](@ref) uses these functions.
