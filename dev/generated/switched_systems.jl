import PathCompleteCertificates as PCC
using Random
using Plots

A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

systems =
    [("autonomous", PCC.switched_system(A)), ("with an input", PCC.switched_system(A, B))]

[
    (name, PCC.has_input(s), PCC.n_modes(s), PCC.n_nodes(PCC.common_graph(s))) for
    (name, s) in systems
]

controlled = systems[2][2]

PCC.state_matrices(controlled) == A, PCC.input_matrices(controlled) == B

PCC.product(controlled, [1, 2]) == A[2] * A[1]

system = systems[1][2]

trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 1, 2])

PCC.switching(trajectory), length(PCC.states(trajectory))

PCC.switching(PCC.simulate(system, [1.0, 1.0], 20; rng = MersenneTwister(42)))

plot(
    PCC.simulate(system, [1.0, 1.0], 25; rng = MersenneTwister(7));
    title = "one run under arbitrary switching",
    lw = 2,
)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
