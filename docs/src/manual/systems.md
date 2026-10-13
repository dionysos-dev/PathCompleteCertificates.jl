```@meta
CurrentModule = PathCompleteCertificates
```

# Switched systems

The input to every problem is a discrete-time switched linear system,
``x_{k+1} = A_{\sigma(k)}\, x_k``, or ``x_{k+1} = A_{\sigma(k)}\, x_k + B_{\sigma(k)}\, u_k``
when there is an input to design. A certificate holds for every switching
signal ``\sigma``: every sequence of modes under **arbitrary switching**, every
path of an automaton under **constrained switching**.
[Switched systems: building and running one](@ref) builds all four
combinations.

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

[`is_invertible`](@ref) tests whether every mode matrix is invertible, which
the composition lifts require for the quadratic and sum-of-squares templates:
composition with a singular matrix does not keep a quadratic form positive
definite.
[`is_positive`](@ref) tests whether every mode matrix is entrywise nonnegative,
which the copositive templates require.

## The language

A certificate graph must read every admissible switching sequence.
[`language`](@ref)`(system)` returns these sequences as an automaton: one state
reading every mode under arbitrary switching, the constraint automaton
otherwise ([philippe2016stability](@cite)). Every problem tests
`is_path_complete(graph, language(system))` before solving.

[`common_graph`](@ref)`(system)` is the smallest graph that reads it: the
common Lyapunov function graph ``G_0``, one node with a loop per mode, under
arbitrary switching, and the automaton itself otherwise. Every path-complete
graph gives a bound at least as good, and [`refine`](@ref) starts from it.

## Runs

[`simulate`](@ref)`(system, x0, modes; u)` runs a switching sequence from a
state and returns a [`Trajectory`](@ref): [`states`](@ref),
[`switching`](@ref) and, when there is an input, [`inputs`](@ref).
`simulate(certificate, x0, steps)` closes the loop with the feedback of an
optimal-control certificate under a random switching sequence. A trajectory
has a plot recipe, available once Plots is loaded;
[Switched systems: building and running one](@ref) draws one.

A run can show that a bound is loose or that a trajectory leaves a set; it
cannot show that no trajectory does.
