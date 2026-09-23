import PathCompleteCertificates as PCC
import Clarabel
using Plots

const OPTIMIZER = Clarabel.Optimizer

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

INITIAL_RADIUS = 4.0
UNSAFE_RADIUS = 6.0

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 INITIAL_RADIUS^2]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -UNSAFE_RADIUS^2]

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)

graph = PCC.de_bruijn(1, 2)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate) || error("no barrier found")

certificate.margin

circle(radius) = (
    radius .* cos.(range(0, 2pi; length = 400)),
    radius .* sin.(range(0, 2pi; length = 400)),
)

figure = plot(;
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
    title = "a path-complete barrier certificate",
    size = (760, 780),
)

plot!(figure, circle(INITIAL_RADIUS)...; lw = 2, ls = :dash, label = "initial set ‖x‖ ≤ 4")
plot!(figure, circle(UNSAFE_RADIUS)...; lw = 2, ls = :dash, label = "unsafe set ‖x‖ ≥ 6")

grid = range(-8, 8; length = 400)
values = [certificate([x, y]) for y in grid, x in grid]

contour!(
    figure,
    grid,
    grid,
    values;
    levels = [0.0],
    lw = 2,
    linecolor = :black,
    colorbar = false,
)

# `contour!` adds no legend entry of its own.
plot!(figure, [NaN], [NaN]; lw = 2, color = :black, label = "barrier, B(x) = 0")

figure

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
