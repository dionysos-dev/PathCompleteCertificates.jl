import PathCompleteCertificates as PCC
import Clarabel
using SumOfSquares, DynamicPolynomials
using HybridSystems
using Plots

const OPTIMIZER = Clarabel.Optimizer

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

graph = GraphAutomaton(1)
add_transition!(graph, 1, 1, 1)
add_transition!(graph, 1, 1, 2)

@polyvar x[1:2]

quadratic = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-4,
)

certificates = map(1:3) do degree
    return PCC.jsr_bound(
        PCC.SumOfSquaresTemplate(degree, x),
        graph,
        problem;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    )
end

[
    ("quadratic", quadratic.rate);
    [("SOS degree $(2d)", c.rate) for (d, c) in zip(1:3, certificates)]
]

function sublevel_boundary(certificate; samples = 721)
    degree = PCC.rate_exponent(PCC.template(certificate))
    angles = range(0, 2pi; length = samples)
    radii = [certificate([cos(a), sin(a)])^(-1 / degree) for a in angles]
    radii ./= maximum(radii)

    return radii .* cos.(angles), radii .* sin.(angles)
end

shapes = plot(;
    title = "one graph, rising degree\n(shape only — scale is arbitrary)",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (degree, certificate) in zip(1:3, certificates)
    xs, ys = sublevel_boundary(certificate)
    plot!(
        shapes,
        xs,
        ys;
        label = "degree $(2degree) — rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

shapes

degrees = 2 .* (1:3)
rates = [c.rate for c in certificates]

plot(
    degrees,
    rates;
    marker = :circle,
    lw = 2,
    label = "sum of squares",
    xlabel = "degree of the node functions",
    ylabel = "certified rate",
    xticks = degrees,
    title = "the bound is non-increasing in the degree",
)
hline!([quadratic.rate]; ls = :dash, lw = 2, label = "quadratic template")

de_bruijn = PCC.de_bruijn(1, 2)

memory = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    de_bruijn,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-4,
)

both = PCC.jsr_bound(
    PCC.SumOfSquaresTemplate(2, x),
    de_bruijn,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-4,
)

[
    ("quadratic, 1 node", quadratic.rate),
    ("degree 4, 1 node", certificates[2].rate),
    ("quadratic, 2 nodes", memory.rate),
    ("degree 4, 2 nodes", both.rate),
]

comparison = plot(;
    title = "both axes\n(shape only — scale is arbitrary)",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (name, certificate) in (
    ("quadratic, 1 node", quadratic),
    ("degree 4, 1 node", certificates[2]),
    ("quadratic, 2 nodes", memory),
    ("degree 4, 2 nodes", both),
)
    xs, ys = sublevel_boundary(certificate)
    plot!(
        comparison,
        xs,
        ys;
        label = "$name — rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

comparison

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
