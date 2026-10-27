import PathCompleteCertificates as PCC
import Clarabel
import JuMP
import Random
using Plots

const TEMPLATE = PCC.QuadraticTemplate()
const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)
nothing #hide

A = [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]]
B = [[1.0; 0.0;;], [1.0; 0.0;;]]
Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]

system = PCC.switched_system(A, B)
problem = PCC.OptimalControlProblem(system, Q, R)
x0 = [3.0, -2.0]
nothing #hide

PCC.certify(TEMPLATE, PCC.common_graph(system), problem; optimizer = OPTIMIZER)(x0)

bounds = [
    PCC.certify(TEMPLATE, PCC.de_bruijn(k, 2), problem; optimizer = OPTIMIZER)(x0) for
    k in 0:2
]

graph = PCC.de_bruijn(1, 2)
certificate = PCC.certify(TEMPLATE, graph, problem; optimizer = OPTIMIZER)
certificate.gains

directions = [[cos(t), sin(t)] for t in range(0, 2pi; length = 400)]
level_set(f, value) = [d .* sqrt(value / f(d)) for d in directions]

left = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the sets V ≤ V(x₀)",
)
for (a, V) in enumerate(PCC.functions(certificate))
    points = level_set(x -> PCC.node_value(problem, V, x), certificate(x0))
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
    trajectory = PCC.simulate(certificate, x0, 30; rng)
    visited, applied = PCC.states(trajectory), PCC.inputs(trajectory)
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

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
