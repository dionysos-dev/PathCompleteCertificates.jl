import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra
import Random
using Plots

const TEMPLATE = PCC.QuadraticTemplate()
const OPTIMIZER = Clarabel.Optimizer
nothing #hide

A = [0.75 * [0.0 1.0; -1.0 0.0], 0.75 * [1.0 1.0; 0.0 1.0]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)
nothing #hide

PCC.certify(TEMPLATE, PCC.common_graph(system), problem; optimizer = OPTIMIZER).rate

rates = [
    PCC.certify(TEMPLATE, PCC.de_bruijn(k, 2), problem; optimizer = OPTIMIZER).rate for
    k in 0:2
]

graph = PCC.de_bruijn(2, 2)
certificate = PCC.certify(TEMPLATE, graph, problem; optimizer = OPTIMIZER)
certificate.rate

directions = [[cos(t), sin(t)] for t in range(0, 2pi; length = 400)]
boundary(f) = [d ./ sqrt(f(d)) for d in directions]

left = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the sets V ≤ 1",
)
for (a, V) in enumerate(PCC.functions(certificate))
    points = boundary(x -> PCC.node_value(problem, V, x))
    plot!(left, first.(points), last.(points); lw = 1, label = "node $a")
end
points = boundary(certificate)
plot!(left, first.(points), last.(points); color = :black, lw = 3, label = "common")

rng = Random.MersenneTwister(1)
right = plot(;
    yscale = :log10,
    xlabel = "step k",
    ylabel = "V(xₖ) / V(x₀)",
    legend = :bottomleft,
    title = "V along switching sequences",
)
for run in 1:100
    states = PCC.states(PCC.simulate(system, [1.0, 0.0], 40; rng))
    plot!(
        right,
        0:40,
        certificate.(states) ./ certificate(states[1]);
        color = :steelblue,
        alpha = 0.3,
        label = run == 1 ? "100 random runs" : "",
    )
end
# Start the repeated sequence on the slowest direction of its product.
slowest = LinearAlgebra.eigen(A[1] * A[2]^4)
x0 = real(slowest.vectors[:, argmax(abs.(slowest.values))])
states = PCC.states(PCC.simulate(system, x0, repeat([2, 2, 2, 2, 1], 8)))
plot!(
    right,
    0:40,
    certificate.(states) ./ certificate(states[1]);
    color = :red,
    lw = 2,
    label = "2, 2, 2, 2, 1, repeated",
)
plot!(
    right,
    0:40,
    certificate.rate .^ (2 .* (0:40));
    color = :black,
    lw = 3,
    ls = :dash,
    label = "γ²ᵏ",
)

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

PCC.jsr_lower_bound(certificate)

lower = maximum(abs, LinearAlgebra.eigvals(A[1] * A[2]^4))^(1 / 5)
lower, certificate.rate

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
