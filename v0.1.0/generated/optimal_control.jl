using PathCompleteCertificates
import Clarabel
import JuMP
import Random
using Plots

const TEMPLATE = QuadraticTemplate()
# Clarabel's chordal decomposition fails on optimal-control programs.
const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)
nothing #hide

A = [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]]
B = [[1.0; 0.0;;], [1.0; 0.0;;]]
Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]

system = switched_system(A, B)
problem = OptimalControlProblem(system, Q, R)
x0 = [3.0, -2.0]
nothing #hide

certify(TEMPLATE, common_graph(system), problem; optimizer = OPTIMIZER)(x0)

bounds =
    [certify(TEMPLATE, de_bruijn(k, 2), problem; optimizer = OPTIMIZER)(x0) for k in 0:2]

graph = de_bruijn(1, 2)
certificate = certify(TEMPLATE, graph, problem; optimizer = OPTIMIZER)
certificate.gains

directions = [[cos(t), sin(t)] for t in range(0, 2pi; length = 400)]
level_set(f, value) = [d .* sqrt(value / f(d)) for d in directions]

left = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the sets V ≤ V(x₀)",
)
for (a, V) in enumerate(functions(certificate))
    points = level_set(x -> node_value(problem, V, x), certificate(x0))
    plot!(
        left,
        first.(points),
        last.(points);
        color = (:darkorange, :purple)[a],
        lw = 2,
        ls = :dash,
        label = "node $a",
    )
end
points = level_set(certificate, certificate(x0))
plot!(left, first.(points), last.(points); color = :black, lw = 3, label = "common")

rng = Random.MersenneTwister(1)
costs = Vector{Float64}[]
for run in 1:100
    trajectory = simulate(certificate, x0, 30; rng)
    visited, applied = states(trajectory), inputs(trajectory)
    stage = [x' * Q * x + u' * R * u for (x, u) in zip(visited, applied)]
    push!(costs, cumsum(stage))
    run <= 20 && plot!(
        left,
        first.(visited),
        last.(visited);
        color = :steelblue,
        alpha = 0.5,
        label = run == 1 ? "20 random runs" : "",
    )
end

right = plot(;
    xlabel = "step k",
    ylabel = "cost up to step k",
    legend = :bottomright,
    title = "cost along switching sequences",
)
for (run, cost) in enumerate(costs)
    plot!(
        right,
        1:30,
        cost;
        color = :steelblue,
        alpha = 0.3,
        label = run == 1 ? "100 random runs" : "",
    )
end
hline!(right, [first(bounds)]; color = :grey, lw = 3, ls = :dot, label = "bound, one node")
hline!(
    right,
    [certificate(x0)];
    color = :black,
    lw = 3,
    ls = :dash,
    label = "bound, order 1",
)

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

maximum(last.(costs)), certificate(x0)

import HiGHS, SetProg, SumOfSquares

library = SetProg.Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)
fixed(template, problem) =
    certify(template, graph, problem; optimizer = OPTIMIZER, gains = certificate.gains)

piecewise_quadratic =
    fixed(PiecewiseQuadraticTemplate(fill(planar_conic_partition(1; library), 2)), problem)
piecewise_linear =
    fixed(PiecewiseLinearTemplate(fill(planar_conic_partition(3), 2)), problem)
piecewise_quadratic(x0), piecewise_linear(x0)

quartic = fixed(
    SumOfSquaresTemplate(2; convex = true),
    OptimalControlProblem(system, Q, R; p = 4),
)
quartic(x0)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
