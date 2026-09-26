import PathCompleteCertificates as PCC
import Clarabel
import JuMP
using Random
using Plots

A = [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]]
B = [[1.0; 0.0;;], [1.0; 0.0;;]]

Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]

OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)

system = PCC.switched_system(A, B)
problem = PCC.OptimalControlProblem(system, Q, R)

graph = PCC.de_bruijn(1, 2; orientation = :complete)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate)

certificate.gains

x = [1.0, 1.0]
certificate(x)

certificate.objective

run = PCC.simulate(certificate, [3.0, -2.0], 25; rng = MersenneTwister(1))

visited = PCC.states(run)
values = [certificate(state) for state in visited]

angles = range(0, 2pi; length = 721)
unit = [certificate([cos(a), sin(a)])^(-1 / 2) for a in angles]

level_set(value) =
    (sqrt(value) .* unit .* cos.(angles), sqrt(value) .* unit .* sin.(angles))

plane = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the run never leaves the set it starts in",
)

plot!(
    plane,
    level_set(first(values))...;
    lw = 2,
    ls = :dash,
    color = :grey,
    label = "bound at the initial state",
)

plot!(
    plane,
    first.(visited),
    last.(visited);
    marker = :circle,
    markersize = 3,
    lw = 2,
    label = "closed loop",
)

descent = plot(
    values;
    marker = :circle,
    markersize = 3,
    lw = 2,
    yscale = :log10,
    legend = false,
    xlabel = "step",
    ylabel = "bound at the state",
    title = "and never back out",
)

plot(plane, descent; layout = (1, 2), size = (900, 460))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
