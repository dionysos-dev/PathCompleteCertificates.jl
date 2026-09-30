import PathCompleteCertificates as PCC
using Random
using Plots

A = [[0.5 0.0; 0.0 0.25], [0.0 1.0; -1.0 0.0]]
system = PCC.switched_system(A)

trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 1, 2])

PCC.switching(trajectory), length(PCC.states(trajectory))

using HybridSystems

constraint = GraphAutomaton(2)             # mode 2 may not follow mode 2
add_transition!(constraint, 1, 1, 1)
add_transition!(constraint, 1, 2, 2)
add_transition!(constraint, 2, 1, 1)

constrained = PCC.switched_system(A; automaton = constraint)

rng = MersenneTwister(42)
word = PCC.switching(PCC.simulate(constrained, [1.0, 1.0], 20; rng = rng))

any(word[k] == 2 && word[k + 1] == 2 for k in 1:(length(word) - 1))

rng = MersenneTwister(7)
run = PCC.simulate(system, [1.0, 1.0], 25; rng = rng)

plot(run; title = "one run of a switched system", lw = 2)

visited = PCC.states(run)

plot(
    getindex.(visited, 1),
    getindex.(visited, 2);
    aspect_ratio = :equal,
    framestyle = :origin,
    marker = :circle,
    markersize = 2,
    lw = 1,
    label = "trajectory",
    title = "the same run, in the plane",
)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
