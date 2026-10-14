```@meta
CurrentModule = PathCompleteCertificates
```

# Switched systems

The input to every problem is a discrete-time switched linear system,
``x_{k+1} = A_{\sigma(k)}\, x_k``, or ``x_{k+1} = A_{\sigma(k)}\, x_k + B_{\sigma(k)}\, u_k``
when there is an input to design. A certificate holds for every switching
signal ``\sigma``: every sequence of modes, under **arbitrary switching**.
Constrained switching, restricted to the paths of an automaton, is not
supported. [Switched systems: building and running one](@ref) builds both
kinds.

## Defining one

[`switched_system`](@ref)`(A)` takes the mode matrices `A[1], …, A[M]`, and
`switched_system(A, B)` the input matrices as well. The result is a
`HybridSystem` of HybridSystems.jl, read back with [`n_modes`](@ref),
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

## The graph to start from

A certificate graph must read every sequence of modes. Every problem tests
`is_path_complete(graph, 1:n_modes(system))` before solving.

[`common_graph`](@ref)`(system)` is the smallest graph that does: the common
Lyapunov function graph ``G_0``, one node with a loop per mode. Every
path-complete graph gives a bound at least as good, and most refinement
algorithms start from it; see [Graph refinement](@ref).

## Runs

[`simulate`](@ref)`(system, x0, modes; u)` runs a switching sequence from a
state and returns a [`Trajectory`](@ref): [`states`](@ref),
[`switching`](@ref) and, when there is an input, [`inputs`](@ref).
`simulate(certificate, x0, modes)` closes the loop with the feedback of an
optimal-control certificate. Given a horizon instead of modes, either draws
each mode uniformly at random. A trajectory
has a plot recipe, available once Plots is loaded;
[Switched systems: building and running one](@ref) draws one.

A run can show that a bound is loose or that a trajectory leaves a set; it
cannot show that no trajectory does.
