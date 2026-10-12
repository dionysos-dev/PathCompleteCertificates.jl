```@meta
CurrentModule = PathCompleteCertificates
```

# Switched systems

The input to every problem is a discrete-time switched linear system,
``x_{k+1} = A_{\sigma(k)}\, x_k``, or ``x_{k+1} = A_{\sigma(k)}\, x_k + B_{\sigma(k)}\, u_k``
when there is an input to design. The switching signal ``\sigma`` is never
chosen by the user: it ranges over every sequence of modes under **arbitrary
switching**, and over the paths of an automaton under **constrained
switching**. [Switched systems: building and running one](@ref) builds all
four combinations.

## Defining one

[`switched_system`](@ref)`(A)` takes the mode matrices `A[1], …, A[M]`, and
`switched_system(A, B)` the input matrices as well; `automaton = ` restricts
the switching to the paths of a `GraphAutomaton` over the same modes. The
result is a `HybridSystem` of HybridSystems.jl, read back with
[`mode_matrices`](@ref), [`input_matrices`](@ref) and [`has_input`](@ref);
[`mode_matrix`](@ref)`(system, word)` is the product of the matrices along a
sequence of modes.

```@docs; canonical=false
switched_system
```

Two properties of the dynamics matter to the graph layer. [`is_invertible`](@ref):
composition with the dynamics keeps a quadratic form positive definite only
for invertible matrices, which is what the composition lifts need.
[`is_positive`](@ref): a positive switched system, one with entrywise
nonnegative matrices, is the setting of the copositive templates.

## The language

A certificate graph must be able to read every admissible switching sequence.
[`language`](@ref)`(system)` returns what it must read, as the system's own
automaton: one state reading every mode under arbitrary switching, the
constraint automaton otherwise ([philippe2016stability](@cite)).
`is_path_complete(graph, language(system))` is the check, and every problem
runs it before solving.

[`common_graph`](@ref)`(system)` is the smallest graph that reads it: the
common Lyapunov function graph ``G_0``, one node with a loop per mode, under
arbitrary switching, and the automaton itself otherwise. Every path-complete
graph is at least as good, and it is where [`refine`](@ref) starts. What
applies to a constrained system is listed in
[What works with what](@ref "What works with what").

## Runs

[`simulate`](@ref)`(system, x0, modes; u)` runs a switching sequence from a
state and returns a [`Trajectory`](@ref): [`states`](@ref),
[`switching`](@ref) and, when there is an input, [`inputs`](@ref).
`simulate(certificate, x0, steps)` closes the loop with the feedback of an
optimal-control certificate under a random switching sequence. A trajectory
has a plot recipe, available once Plots is loaded;
[Switched systems: building and running one](@ref) draws one.

A run is a sample, never a proof. It can show that a bound is loose or that a
trajectory leaves a set; it cannot show that none does. The proofs are the
certificates.
