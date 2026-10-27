import PathCompleteCertificates as PCC
import Clarabel
import Random
using Plots

const TEMPLATE = PCC.QuadraticTemplate()
const OPTIMIZER = Clarabel.Optimizer
nothing #hide

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
system = PCC.switched_system(A)

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]
problem = PCC.SafetyProblem(system, S0, Su)
nothing #hide

PCC.is_feasible(
    PCC.certify(TEMPLATE, PCC.common_graph(system), problem; optimizer = OPTIMIZER),
)

graph = PCC.de_bruijn(1, 2)
certificate = PCC.certify(TEMPLATE, graph, problem; optimizer = OPTIMIZER)
PCC.is_feasible(certificate), certificate.margin

grid = range(-7, 7; length = 300)
disk(radius) = Shape(
    radius .* cos.(range(0, 2pi; length = 200)),
    radius .* sin.(range(0, 2pi; length = 200)),
)

left = plot(;
    aspect_ratio = :equal,
    framestyle = :box,
    xlims = (-7, 7),
    ylims = (-7, 7),
    legend = :outerbottom,
    title = "the zero sets B = 0",
)
plot!(
    left,
    Shape([-7, 7, 7, -7], [-7, -7, 7, 7]);
    color = :red,
    alpha = 0.2,
    linealpha = 0,
    label = "unsafe set, ‖x‖ ≥ 6",
)
plot!(left, disk(6.0); color = :white, linecolor = :red, label = "")
plot!(left, disk(4.0); color = :green, alpha = 0.3, label = "initial set, ‖x‖ ≤ 4")
contour!(
    left,
    grid,
    grid,
    [certificate([x, y]) for y in grid, x in grid];
    levels = [0.0],
    color = :black,
    lw = 4,
    colorbar = false,
)
# `contour!` adds no legend entry of its own.
plot!(left, [NaN], [NaN]; color = :black, lw = 4, label = "common")
for (a, V) in enumerate(PCC.functions(certificate))
    color = (:darkorange, :purple)[a]
    values = [PCC.node_value(problem, V, [x, y]) for y in grid, x in grid]
    contour!(
        left,
        grid,
        grid,
        values;
        levels = [0.0],
        color,
        lw = 2,
        ls = :dash,
        colorbar = false,
    )
    plot!(left, [NaN], [NaN]; color, lw = 2, ls = :dash, label = "node $a")
end

rng = Random.MersenneTwister(1)
right = plot(;
    xlabel = "step k",
    ylabel = "B(xₖ)",
    legend = :bottomright,
    title = "B along switching sequences",
)
for run in 1:100
    angle = 2pi * run / 100
    visited = PCC.states(PCC.simulate(system, 4 .* [cos(angle), sin(angle)], 30; rng))
    plot!(
        right,
        0:30,
        certificate.(visited);
        color = :steelblue,
        alpha = 0.3,
        label = run == 1 ? "100 random runs" : "",
    )
end
hline!(right, [0.0]; color = :black, lw = 3, ls = :dash, label = "B = 0")

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

PCC.certify(TEMPLATE, PCC.de_bruijn(2, 2), problem; optimizer = OPTIMIZER).margin

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
