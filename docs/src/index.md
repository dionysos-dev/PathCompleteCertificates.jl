```@meta
CurrentModule = PathCompleteCertificates
```

# PathCompleteCertificates.jl

Certificates for switched systems, built on **path-complete graphs**, with the
graph as the object you work on: build one, compare it with another, and
refine it against its own certificate.

## One structure, three problems

A switched linear system moves among a finite set of modes,
``x_{k+1} = A_{\sigma(k)}\, x_k``, and the switching sequence ``\sigma`` is not
yours to choose. A guarantee has to hold for every sequence. A path-complete
certificate is always the same three things:

1. a **labelled graph** whose labels are the modes;
2. a function ``V_s`` at each node, drawn from a **template**;
3. one **inequality along each edge**, fixed by the **problem**.

When the graph is **path-complete**, meaning every switching sequence can be
read as a path in it, the edge inequalities, which are local, imply a property
of the whole system ([ahmadi2014joint](@cite)). Only the inequality changes
between problems:

| Problem | Edge inequality on ``(s, d, i)`` | What the certificate carries |
| :-- | :-- | :-- |
| [`StabilityProblem`](@ref) | ``V_d(A_i x) \le \gamma^{d}\, V_s(x)`` | `rate`, an upper bound on the joint spectral radius |
| [`SafetyProblem`](@ref) | ``B_d(A_i x) \le B_s(x)``, plus separation of the initial and unsafe sets | `margin`, how strictly the sets are separated |
| [`OptimalControlProblem`](@ref) | ``x^\top Q x + u^\top R u + V_d(A_i x + B_i u) \le V_s(x)`` | `gains`, a feedback per node, under the bound ``V`` |

The graph, the templates and the aggregation of node functions into one
common function are shared. So the package is organised along two independent
axes, **templates** and **problems**, and the graph cuts across both.

## What you can do

| | Acts on | Does | Read |
| :-- | :-- | :-- | :-- |
| **Certify** | a template, a graph and a problem | solve for a certificate on the graph, with any template the problem accepts | [Problems](@ref); [Stability: a first certificate](@ref) |
| **Build** | a system, or nothing | De Bruijn graphs, the seed of a system, duals, graphs reading words, graphs for constrained switching | [Path-complete graphs](@ref) |
| **Compare** | two graphs, and optionally templates | decide whether one graph is no worse than the other, for which templates, with the witness | [Comparing graphs](@ref); [Comparing graphs: which one is better?](@ref) |
| **Refine** | a template, a graph and a problem | grow the graph where its certificate is tight, with any refinement of the literature, until the bound is proved exact | [Refinement: designing the graph](@ref); [Refinement: letting the graph design itself](@ref) |

```
   system ──┐                                     ┌─▶ rate, margin or gains
 template ──┼─▶ certify ─▶ certificate ───────────┤
    graph ──┘      ▲                              └─▶ common function, slacks, tight edges
      ▲            │                                             │
      │       dual · compare                                     │
      └───────────────────────────── refine ◀────────────────────┘
```

Comparing two graphs needs no solver beyond a linear program, and its verdict
holds for every system at once: it is decided by a simulation between a
*lift* of one graph and the other, one lift per closure property a template
may declare. Refining a graph is solver-driven: each step reads where the
certificate is tight and applies a *refinement*, a transformation that is no
worse for every template.

## Where to start

In reading order:

1. [Switched systems: the four kinds](@ref), arbitrary or constrained
   switching, with or without an input.
2. [Stability: a first certificate](@ref), one system, one graph, one bound.
3. [The two axes, drawn](@ref), three templates on one graph and one template
   on four graphs.
4. [Comparing graphs: which one is better?](@ref), five graphs, three
   templates, a witness for every verdict.
5. [Refinement: letting the graph design itself](@ref), the graph grown from
   its certificate, against De Bruijn at equal size.

The other examples cover [safety](@ref "Safety: a barrier certificate"),
[optimal control](@ref "Optimal control: bounding the value function"),
[simulation](@ref "Simulating: what a run looks like") and
[the sum-of-squares hierarchy](@ref "The sum-of-squares hierarchy").

## Scope

Stability, safety and optimal control are solved; [What works with what](@ref)
says which template each accepts. The graph layer, comparing, refining and
words on edges, is written for stability, where the theory is.

Three things to know before reading a result. A template is passed as an
instance, never as a type, because some carry data. A bound is always an upper
bound. A negative answer means no certificate was found in this template on
this graph, never that the property fails.

## Other tools

[SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl) and the MATLAB
[JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)
compute joint-spectral-radius bounds with methods beyond path-complete graphs,
and use such a graph, when they do, as an internal device. This package is
complementary: it makes the graph a first-class object, independent of the
system, and treats the three problems as instances of one structure.

## Installation

Not yet registered.

```julia
] add https://github.com/dionysos-dev/PathCompleteCertificates.jl
```

```@docs
PathCompleteCertificates
```
