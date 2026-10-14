```@meta
CurrentModule = PathCompleteCertificates
```

# PathCompleteCertificates.jl

Certificates of stability, safety and optimal control for switched systems in
the path-complete framework. A certificate consists of a **graph** and a
**template**, both chosen by the user. The package solves for a certificate on
a given graph and template, refines a graph using its certificate, and compares
two graphs.

## Path-complete certificates

A switched linear system evolves according to
``x_{k+1} = A_{\sigma(k)}\, x_k``, where ``\sigma`` is a switching signal taking
values in a finite set of modes, under arbitrary switching. A certificate must
hold for every switching sequence.
In the path-complete framework ([ahmadi2014joint](@cite))
a certificate is specified by three ingredients:

1. a **labelled graph** whose labels are the modes;
2. a function ``V_s`` at each node, drawn from a **template**;
3. one **inequality along each edge**, determined by the **problem**.

When the graph is **path-complete**, meaning that every admissible switching
sequence can be read as a path in it, these local inequalities imply a property
of the whole system. The three problems differ in the edge inequality and in
the conditions on the node functions:

| Problem | Edge inequality on ``(s, d, i)`` | Conditions on the node functions | The certificate carries |
| :-- | :-- | :-- | :-- |
| [`StabilityProblem`](@ref) | ``V_d(A_i x) \le \gamma^{p}\, V_s(x)`` | positive definite, homogeneous of degree ``p`` | `rate`, an upper bound on the joint spectral radius |
| [`SafetyProblem`](@ref) | ``B_d(A_i x) \le B_s(x)`` | negative on the initial set, positive on the unsafe set | `margin`, how strictly the two sets are separated |
| [`OptimalControlProblem`](@ref) | ``x^\top Q x + u^\top R u + V_d(A_i x + B_i u) \le V_s(x)`` | positive definite quadratic | `gains`, a feedback per node, and the bound ``V`` on the cost |

## What you can do

| | Takes | Gives |
| :-- | :-- | :-- |
| **Certify** | a template, a graph and a problem | a certificate: the node functions, what the problem certifies (`rate`, `margin` or `gains`), and the common function, evaluated by calling the certificate `c` as `c(x)` |
| **Build** | an order and an alphabet, or a system | De Bruijn graphs and their duals, the common Lyapunov function graph, graphs with words on their edges |
| **Refine** | a template, a graph and a problem | a sequence of graphs, each lifted where its certificate is tight, until the bound is proved exact or a budget is reached |
| **Compare** | two graphs, and optionally templates and a system | whether the second graph is no worse than the first, for which templates, and the simulation that proves it |

The manual follows the same order: [Switched systems](@ref),
[Path-complete graphs](@ref), [Templates](@ref) and [Problems](@ref) for
certifying, then [Lifts](@ref), [Graph refinement](@ref) and
[Graph comparison via lifts](@ref).

## Where to start

In reading order:

1. [Switched systems: building and running one](@ref), the two kinds of
   system and a run of one.
2. [Stability: a first certificate](@ref), one system, one graph, one bound.
3. [Templates and graphs: the two axes](@ref), three templates on one graph,
   one template on four graphs, and a sum-of-squares template.
4. [Refinement: splitting nodes at tight edges](@ref), [`refine`](@ref)
   compared with a De Bruijn graph of the same size.
5. [Comparing graphs: five graphs, three templates](@ref), the five graphs of
   [debauche2023ordering](@cite) compared for three templates, with the
   simulation behind each result.

Safety and optimal control have one example each,
[Safety: a barrier certificate](@ref) and
[Optimal control: a feedback per node](@ref), and so does the SetProg
template, [Piecewise semi-ellipsoids: a template from SetProg](@ref).

## Scope

Stability is implemented for every template, safety and optimal control for
the quadratic one. [`compare`](@ref) is stated for stability, as in the
literature, and [`refine`](@ref) runs on stability and safety;
[What works with what](@ref) gives the full table. A bound is always an upper
bound, and a negative answer means that no certificate was found in this
template on this graph, not that the property fails.

## Other tools

[SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl) and the MATLAB
[JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)
compute bounds on the joint spectral radius by several methods, some of which
use path-complete graphs. This package is restricted to path-complete
certificates, and adds the comparison and refinement of their graphs.

## Installation

Not yet registered.

```julia
] add https://github.com/dionysos-dev/PathCompleteCertificates.jl
```

```@docs
PathCompleteCertificates
```
