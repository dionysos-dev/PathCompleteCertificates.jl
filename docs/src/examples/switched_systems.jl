# # Switched systems: building and running one
#
# Every problem takes a switched linear system under arbitrary switching, with
# a continuous input or not. [`switched_system`](@ref) builds both kinds, and
# [`simulate`](@ref) computes a trajectory along a switching sequence.

import PathCompleteCertificates as PCC
using Random
using Plots

# Two modes on the plane: the first contracts along `y` and fixes `x`, the
# second contracts along `x` and fixes `y`.

A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

# ## The two kinds
#
# A certificate graph must read every word over the [`n_modes`](@ref) modes.
# [`common_graph`](@ref) is the smallest graph that does: one node with a loop
# per mode.

systems =
    [("autonomous", PCC.switched_system(A)), ("with an input", PCC.switched_system(A, B))]

[
    (name, PCC.has_input(s), PCC.n_modes(s), PCC.n_nodes(PCC.common_graph(s))) for
    (name, s) in systems
]

# The matrices are read back with [`state_matrices`](@ref) and
# [`input_matrices`](@ref); [`state_matrix`](@ref) gives the product along a
# sequence of modes.

controlled = systems[2][2]

PCC.state_matrices(controlled) == A, PCC.input_matrices(controlled) == B

#-

PCC.state_matrix(controlled, [1, 2]) == A[2] * A[1]

# ## Running one
#
# Given a sequence of modes, `simulate` computes the trajectory along that
# sequence.

system = systems[1][2]

trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 1, 2])

PCC.switching(trajectory), length(PCC.states(trajectory))

# Given a horizon instead, it draws the modes uniformly at random.

PCC.switching(PCC.simulate(system, [1.0, 1.0], 20; rng = MersenneTwister(42)))

# A [`Trajectory`](@ref) has a plot recipe, available once Plots is loaded.

plot(
    PCC.simulate(system, [1.0, 1.0], 25; rng = MersenneTwister(7));
    title = "one run under arbitrary switching",
    lw = 2,
)

# A trajectory follows one switching sequence. It can show that a bound is
# loose or that a trajectory leaves a set, but not that no trajectory does;
# that requires a certificate, as in [Stability: a first certificate](@ref).
