```@meta
CurrentModule = PathCompleteCertificates
```

# Switched systems

The input to every problem: a discrete-time switched linear system, with or
without an input you control, under arbitrary or constrained switching.
[Switched systems: the four kinds](@ref) builds all four.

## Defining one

[`switched_system`](@ref)`(A)` is ``x_{k+1} = A_{\sigma(k)}\, x_k`` over the
mode matrices `A[1], …, A[M]`, and [`switched_system`](@ref)`(A, B)` is
``x_{k+1} = A_{\sigma(k)}\, x_k + B_{\sigma(k)}\, u_k``. Switching is
**autonomous** in both: the mode is not yours to choose, the input is. Both
are a `HybridSystem` of HybridSystems.jl; [`mode_matrices`](@ref),
[`input_matrices`](@ref) and [`has_input`](@ref) read them back, and
[`mode_matrix`](@ref)`(system, word)` is the product along a sequence of
modes.

```@docs; canonical=false
switched_system
```

Two properties of the dynamics decide what the graph layer may do with a
system. [`is_invertible`](@ref) is what composition with the dynamics needs to
keep a quadratic form positive definite, so it gates the composition lifts.
[`is_nonnegative`](@ref) is a positive system, the setting of the copositive
templates.

## The language

Under **arbitrary switching** every sequence of modes is admissible. Under
**constrained switching** the admissible sequences are the paths of an
automaton over the same alphabet, passed as `automaton =`
([philippe2016stability](@cite)); the automaton of the example forbids mode 2
twice in a row. [`language`](@ref)`(system)` returns what a certificate graph
must read in either case, and every problem checks the graph against it.

[`seed`](@ref)`(system)` is the first graph that reads it: one node with a
loop per mode when switching is arbitrary, the automaton itself otherwise. It
is where [`refine`](@ref) starts, and every lift preserves what it reads.

## Runs

[`simulate`](@ref)`(system, x0, modes; u)` runs a switching sequence from a
state and returns a [`Trajectory`](@ref): [`states`](@ref),
[`switching`](@ref) and, when there is an input, [`inputs`](@ref).
`simulate(certificate, x0, steps)` closes the loop with the feedback of an
optimal-control certificate under a random switching sequence. A trajectory
has a plot recipe, available once Plots is loaded.
[Simulating: what a run looks like](@ref) draws both.

A run is a sample, never a proof. It can show that a bound is loose or that a
trajectory leaves a set; it cannot show that none does. The proofs are the
certificates.

## The dual system

[`dual`](@ref)`(system)` transposes every mode matrix and reverses the
automaton. A certificate for it on the dual graph, in the dual template, is a
certificate for the system ([debauche2024thesis](@cite), Lemma 6.25); see
[Duality](@ref).
