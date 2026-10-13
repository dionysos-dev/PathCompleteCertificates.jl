# # Switched systems: building and running one
#
# Every problem takes a switched linear system. Its switching is arbitrary or
# constrained by an automaton, and it has a continuous input or not.
# [`switched_system`](@ref) builds the four combinations, and
# [`simulate`](@ref) computes a trajectory along a switching sequence.

import PathCompleteCertificates as PCC
using HybridSystems
using Random
using Plots

# Two modes on the plane: the first contracts along `y` and fixes `x`, the
# second contracts along `x` and fixes `y`.

A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

# A constraint automaton over the same modes says which switching sequences the
# plant can produce. This one forbids mode 2 twice in a row.

constraint = GraphAutomaton(2)
add_transition!(constraint, 1, 1, 1)
add_transition!(constraint, 1, 2, 2)
add_transition!(constraint, 2, 1, 1)

# ## The four kinds
#
# A certificate graph must read the system's [`language`](@ref): every word
# over the modes under arbitrary switching, the paths of the automaton under
# constrained switching. [`common_graph`](@ref) is the smallest graph that
# does, one node under arbitrary switching and the automaton itself otherwise.

systems = [
    ("arbitrary", PCC.switched_system(A)),
    ("arbitrary, with an input", PCC.switched_system(A, B)),
    ("constrained", PCC.switched_system(A; automaton = constraint)),
    ("constrained, with an input", PCC.switched_system(A, B; automaton = constraint)),
]

[(name, PCC.has_input(s), PCC.n_nodes(PCC.common_graph(s))) for (name, s) in systems]

# The matrices are read back with [`mode_matrices`](@ref) and
# [`input_matrices`](@ref); [`mode_matrix`](@ref) gives the product along a
# sequence of modes.

controlled = systems[2][2]

PCC.mode_matrices(controlled) == A, PCC.input_matrices(controlled) == B

#-

PCC.mode_matrix(controlled, [1, 2]) == A[2] * A[1]

# !!! note "Two automata, easily confused"
#     The automaton of a constrained system describes which switching
#     sequences the *plant* can produce. The path-complete graph handed to a
#     certificate is a different object of the same type; the argument name
#     says which is wanted.

# ## Running one
#
# Given a sequence of modes, `simulate` computes the trajectory along that
# sequence.

system = systems[3][2]

trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 1, 2])

PCC.switching(trajectory), length(PCC.states(trajectory))

# Given a horizon instead, it draws the modes at random among the sequences
# the automaton admits, so no two consecutive modes are `2`.

word = PCC.switching(PCC.simulate(system, [1.0, 1.0], 20; rng = MersenneTwister(42)))

any(word[k] == 2 && word[k + 1] == 2 for k in 1:(length(word) - 1))

# A [`Trajectory`](@ref) has a plot recipe, available once Plots is loaded.

plot(
    PCC.simulate(system, [1.0, 1.0], 25; rng = MersenneTwister(7));
    title = "one run under constrained switching",
    lw = 2,
)

# A trajectory follows one switching sequence. It can show that a bound is
# loose or that a trajectory leaves a set, but not that no trajectory does;
# that requires a certificate, as in [Stability: a first certificate](@ref).
