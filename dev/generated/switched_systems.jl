import PathCompleteCertificates as PCC
using HybridSystems
using Random
using Plots

A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

constraint = GraphAutomaton(2)
add_transition!(constraint, 1, 1, 1)
add_transition!(constraint, 1, 2, 2)
add_transition!(constraint, 2, 1, 1)

systems = [
    ("arbitrary", PCC.switched_system(A)),
    ("arbitrary, with an input", PCC.switched_system(A, B)),
    ("constrained", PCC.switched_system(A; automaton = constraint)),
    ("constrained, with an input", PCC.switched_system(A, B; automaton = constraint)),
]

[(name, PCC.has_input(s), PCC.n_nodes(PCC.common_graph(s))) for (name, s) in systems]

controlled = systems[2][2]

PCC.mode_matrices(controlled) == A, PCC.input_matrices(controlled) == B

PCC.mode_matrix(controlled, [1, 2]) == A[2] * A[1]

system = systems[3][2]

trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 1, 2])

PCC.switching(trajectory), length(PCC.states(trajectory))

word = PCC.switching(PCC.simulate(system, [1.0, 1.0], 20; rng = MersenneTwister(42)))

any(word[k] == 2 && word[k + 1] == 2 for k in 1:(length(word) - 1))

plot(
    PCC.simulate(system, [1.0, 1.0], 25; rng = MersenneTwister(7));
    title = "one run under constrained switching",
    lw = 2,
)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
