# Figure "One graph, one template, three problems" of the HSCC'27 tool paper
# (Section 5.1): stability, safety and optimal control certified on the De Bruijn
# graph of order 1 with the quadratic template.
#
# Run from the repository root:
#
#     julia --project=numerical_experiments numerical_experiments/three_problems.jl
#
# Prints the numbers quoted in the text (rate, margin, cost bound V(x0) and the
# largest simulated cost) and writes numerical_experiments/results/three_problems.pdf.

import PathCompleteCertificates as PCC
import Clarabel, JuMP
using LinearAlgebra
using Random
using Plots

gr()
const OUT = joinpath(@__DIR__, "results")
mkpath(OUT)

# Categorical slots 1-3 of the validated reference palette, plus neutrals.
const BLUE = colorant"#2a78d6"
const ORANGE = colorant"#eb6834"
const AQUA = colorant"#1baf7a"
const INK = colorant"#52514e"
const GRID = colorant"#d9d8d4"

default(;
    fontfamily = "Computer Modern",
    titlefontsize = 9,
    guidefontsize = 8,
    tickfontsize = 7,
    legendfontsize = 7,
    linewidth = 1.5,
    framestyle = :box,
    grid = true,
    gridcolor = GRID,
    gridalpha = 0.6,
    foreground_color_legend = nothing,
    background_color_legend = RGBA(1, 1, 1, 0.85),
)

const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    # the chordal decomposition of Clarabel 0.11 fails on these programs
    "chordal_decomposition_enable" => false,
    "verbose" => false,
)
const TEMPLATE = PCC.QuadraticTemplate()

angles = range(0, 2pi; length = 721)
circle(r) = (r .* cos.(angles), r .* sin.(angles))

# Boundary of {x : V(x) <= level} for V positively homogeneous of degree d.
function level_curve(V, degree, level = 1.0)
    radii = [(level / V([cos(a), sin(a)]))^(1 / degree) for a in angles]
    return radii .* cos.(angles), radii .* sin.(angles)
end

# ---------------------------------------------------------------------------
# Figure 1: one graph, one template, three problems
# ---------------------------------------------------------------------------

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
B = [[1.0; 0.0;;], [1.0; 0.0;;]]
S0 = [-1.0 0 0; 0 -1.0 0; 0 0 16.0]   # ||x|| <= 4
Su = [1.0 0 0; 0 1.0 0; 0 0 -36.0]    # ||x|| >= 6

graph = PCC.de_bruijn(1, 2)
system = PCC.switched_system(A)

stability = PCC.StabilityProblem(system)
safety = PCC.SafetyProblem(system, S0, Su)
control = PCC.OptimalControlProblem(PCC.switched_system(A, B), [1.0 0; 0 1.0], [1.0;;])

c_stab = PCC.certify(TEMPLATE, graph, stability; optimizer = OPTIMIZER, rtol = 1e-4)
c_safe = PCC.certify(TEMPLATE, graph, safety; optimizer = OPTIMIZER)
c_ctrl = PCC.certify(TEMPLATE, graph, control; optimizer = OPTIMIZER)

println("stability rate      = ", c_stab.rate)
println("safety margin       = ", c_safe.margin)

# (a) Stability: the sublevel set of the common function and its images.
V = c_stab
xs, ys = level_curve(V, 2)
scale = maximum(hypot.(xs, ys))
xs, ys = xs ./ scale, ys ./ scale
boundary = [[x, y] for (x, y) in zip(xs, ys)]

pa = plot(;
    aspect_ratio = :equal,
    title = "(a) stability",
    xlabel = "\$x_1\$",
    ylabel = "\$x_2\$",
    xlims = (-1.15, 1.15),
    ylims = (-1.15, 1.15),
    legend = (0.0, -0.30),
    legend_columns = 2,
)
plot!(
    pa,
    Shape(xs, ys);
    fillcolor = BLUE,
    fillalpha = 0.15,
    linecolor = BLUE,
    lw = 2,
    label = "\$\\{V \\leq 1\\}\$",
)
for (i, color) in ((1, ORANGE), (2, AQUA))
    image = [A[i] * x for x in boundary]
    plot!(
        pa,
        first.(image),
        last.(image);
        color,
        lw = 1.5,
        ls = :dash,
        label = "\$A_$i\\{V \\leq 1\\}\$",
    )
end

# (b) Safety: initial set, unsafe set, zero level set of the barrier, runs.
lim = 8.0
pb = plot(;
    aspect_ratio = :equal,
    title = "(b) safety",
    xlabel = "\$x_1\$",
    ylabel = "\$x_2\$",
    xlims = (-lim, lim),
    ylims = (-lim, lim),
    legend = (0.0, -0.30),
    legend_columns = 2,
)
outer = [(-lim, -lim), (lim, -lim), (lim, lim), (-lim, lim)]
cx, cy = circle(6.0)
plot!(
    pb,
    Shape(vcat(first.(outer), -lim, cx, -lim), vcat(last.(outer), -lim, cy, -lim));
    fillcolor = ORANGE,
    fillalpha = 0.10,
    linecolor = nothing,
    label = "",
)
plot!(pb, cx, cy; color = ORANGE, lw = 1.5, label = "unsafe set")
ix, iy = circle(4.0)
plot!(
    pb,
    Shape(ix, iy);
    fillcolor = AQUA,
    fillalpha = 0.2,
    linecolor = AQUA,
    lw = 1.5,
    label = "initial set",
)

rng = MersenneTwister(2)
for start in range(0, 2pi; length = 13)[1:(end - 1)]
    run = PCC.simulate(system, 4.0 .* [cos(start), sin(start)], 40; rng)
    s = PCC.states(run)
    plot!(pb, first.(s), last.(s); color = INK, alpha = 0.45, lw = 0.7, label = "")
end
plot!(pb, [NaN], [NaN]; color = INK, alpha = 0.45, lw = 0.7, label = "trajectories")

grid = range(-lim, lim; length = 401)
values = [c_safe([x, y]) for y in grid, x in grid]
contour!(pb, grid, grid, values; levels = [0.0], color = BLUE, lw = 2, colorbar = false)
plot!(pb, [NaN], [NaN]; color = BLUE, lw = 2, label = "\$V(x) = 0\$")

# (c) Optimal control: running cost of closed-loop runs under random switching,
# against the certified bound at x0.
x0 = [3.0, -2.0]
bound = c_ctrl(x0)
println("control bound V(x0) = ", bound, " at x0 = ", x0)

Q, R = [1.0 0; 0 1.0], [1.0;;]
horizon = 60
running = Vector{Float64}[]
for seed in 1:200
    run = PCC.simulate(c_ctrl, x0, horizon; rng = MersenneTwister(seed))
    s, u = PCC.states(run), PCC.inputs(run)
    push!(
        running,
        cumsum([dot(s[k], Q * s[k]) + dot(u[k], R * u[k]) for k in eachindex(u)]),
    )
end
costs = last.(running)

shown = 10
ymax = 1.25 * bound
pc = plot(;
    title = "(c) optimal control",
    xlabel = "step \$k\$",
    ylabel = "cost up to \$k\$",
    xlims = (0, shown),
    ylims = (0, ymax),
    aspect_ratio = shown / ymax,
    legend = (0.0, -0.30),
    legend_columns = 2,
)
plot!(
    pc,
    Shape([0, shown, shown, 0], [bound, bound, ymax, ymax]);
    fillcolor = ORANGE,
    fillalpha = 0.10,
    linecolor = nothing,
    label = "",
)
for r in running
    plot!(pc, 0:shown, vcat(0.0, r[1:shown]); color = INK, lw = 0.7, label = "")
end
plot!(pc, [NaN], [NaN]; color = INK, lw = 0.7, label = "closed loop")
hline!(pc, [bound]; color = BLUE, lw = 2, label = "\$V(x_0)\$")
println(
    "sampled closed-loop costs: max = ",
    maximum(costs),
    ", mean = ",
    sum(costs) / length(costs),
    " (bound ",
    bound,
    ")",
)
println(
    "running cost at step $shown / $horizon: max = ",
    maximum(r[shown] for r in running),
    " / ",
    maximum(costs),
)

fig1 = plot(
    pa,
    pb,
    pc;
    layout = (1, 3),
    size = (720, 255),
    left_margin = 2Plots.mm,
    bottom_margin = 12Plots.mm,
)
savefig(fig1, joinpath(OUT, "three_problems.pdf"))
