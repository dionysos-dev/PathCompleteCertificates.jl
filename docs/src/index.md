```@meta
CurrentModule = PathCompleteCertificates
```

# PathCompleteCertificates.jl

Tools for constructing, comparing and refining certificates for switched
systems within the path-complete framework. A certificate has two
complementary components, a **template** and a **graph**; the package makes
both explicit, so that their interplay, for stability, safety and optimal
control, can be studied rather than left inside a solver.

## One structure, three problems

A switched linear system evolves according to
``x_{k+1} = A_{\sigma(k)}\, x_k``, where ``\sigma`` is a switching signal taking
values in a finite set of modes, either arbitrary or constrained to the paths of
an automaton. A certificate must therefore hold uniformly over all admissible
switching sequences. In the path-complete framework ([ahmadi2014joint](@cite))
a certificate is specified by three ingredients:

1. a **labelled graph** whose labels are the modes;
2. a function ``V_s`` at each node, drawn from a **template**;
3. one **inequality along each edge**, determined by the **problem**.

When the graph is **path-complete**, meaning that every admissible switching
sequence can be read as a path in it, these local inequalities imply a property
of the whole system. The same structure serves every certification problem;
only the edge inequality and the conditions on the node functions change:

| Problem | Edge inequality on ``(s, d, i)`` | Conditions on the node functions | The certificate carries |
| :-- | :-- | :-- | :-- |
| [`StabilityProblem`](@ref) | ``V_d(A_i x) \le \gamma^{d}\, V_s(x)`` | positive definite, homogeneous of degree ``d`` | `rate`, an upper bound on the joint spectral radius |
| [`SafetyProblem`](@ref) | ``B_d(A_i x) \le B_s(x)`` | negative on the initial set, positive on the unsafe set | `margin`, how strictly the two sets are separated |
| [`OptimalControlProblem`](@ref) | ``x^\top Q x + u^\top R u + V_d(A_i x + B_i u) \le V_s(x)`` | positive definite quadratic | `gains`, a feedback per node, and the bound ``V`` on the cost |

## What you can do

| | Takes | Gives |
| :-- | :-- | :-- |
| **Certify** | a template, a graph and a problem | a certificate: the node functions, what the problem certifies (`rate`, `margin` or `gains`) and the common function `certificate(x)` |
| **Build** | an order and an alphabet, or a system | De Bruijn graphs and their duals, the common Lyapunov function graph, the automaton of a constrained system as a graph, graphs with words on their edges |
| **Compare** | two graphs, and optionally templates and a system | whether the second graph is no worse than the first, for which templates, and the simulation that proves it |
| **Refine** | a template, a graph and a problem | a sequence of graphs, each refined where its certificate is tight, until the bound is proved exact or a budget is reached |

The manual follows the same order: [Switched systems](@ref),
[Path-complete graphs](@ref), [Templates](@ref) and [Problems](@ref) for
certifying, then [Graph comparison via lifts](@ref) and
[Graph improvement via refinements](@ref).

## Where to start

In reading order:

1. [Switched systems: the four kinds](@ref), arbitrary or constrained
   switching, with or without an input.
2. [Stability: a first certificate](@ref), one system, one graph, one bound.
3. [The two axes, drawn](@ref), three templates on one graph and one template
   on four graphs.
4. [Comparing graphs: which one is better?](@ref), five graphs, three
   templates, a simulation for every verdict.
5. [Refinement: letting the graph design itself](@ref), the graph grown from
   its certificate, against De Bruijn at equal size.

The other examples cover [safety](@ref "Safety: a barrier certificate"),
[optimal control](@ref "Optimal control: bounding the value function"),
[simulation](@ref "Simulating: what a run looks like") and
[the sum-of-squares hierarchy](@ref "The sum-of-squares hierarchy").

## Scope

The path-complete framework has been developed for several problems and
several templates, not always together. Here stability runs on every
template, safety and optimal control on the quadratic one, and comparing and
refining graphs is written for stability, where the theory is;
[What works with what](@ref) is the table. Three things to know before reading
a result: a template is passed as an instance, never as a type; a bound is
always an upper bound; a negative answer means no certificate was found in this
template on this graph, never that the property fails.

## Other tools

[SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl) and the MATLAB
[JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)
compute joint-spectral-radius bounds with methods beyond path-complete graphs,
and use such a graph, when they do, as an internal device. This package treats
the graph as an object in its own right, to be built, compared and refined,
and the three problems as instances of one structure.

## Installation

Not yet registered.

```julia
] add https://github.com/dionysos-dev/PathCompleteCertificates.jl
```

```@docs
PathCompleteCertificates
```
