import PathCompleteCertificates as PCC
import Clarabel
using HybridSystems
using Plots

const OPTIMIZER = Clarabel.Optimizer

function sublevel_boundary(certificate; samples = 721)
    degree = PCC.rate_exponent(PCC.template(certificate))
    angles = range(0, 2pi; length = samples)
    radii = [certificate([cos(a), sin(a)])^(-1 / degree) for a in angles]
    radii ./= maximum(radii)

    return radii .* cos.(angles), radii .* sin.(angles)
end

THETA = pi / 3
ROTATION = [0.9 * [cos(THETA) -sin(THETA); sin(THETA) cos(THETA)]]

rotation_graph = GraphAutomaton(1)
add_transition!(rotation_graph, 1, 1, 1)

rotation_problem = PCC.StabilityProblem(PCC.switched_system(ROTATION))

templates = [
    ("quadratic", PCC.QuadraticTemplate()),
    ("polyhedral, fixed facets", PCC.PolyhedralTemplate(1, 2)),
    (
        "polyhedral, free facets",
        PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(3)]),
    ),
]

left = plot(;
    title = "one graph, three templates\n(shape only — scale is arbitrary)",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (name, template) in templates
    certificate = PCC.jsr_bound(
        template,
        rotation_graph,
        rotation_problem;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    )

    xs, ys = sublevel_boundary(certificate)
    plot!(
        left,
        xs,
        ys;
        label = "$name — rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

left

MIXED = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]

mixed_problem = PCC.StabilityProblem(PCC.switched_system(MIXED))

memoryless = GraphAutomaton(1)
add_transition!(memoryless, 1, 1, 1)
add_transition!(memoryless, 1, 1, 2)

graphs = [("no memory", memoryless)]
for order in 1:3
    push!(graphs, ("memory $order", PCC.de_bruijn(order, 2)))
end

right = plot(;
    title = "one template, four graphs\n(shape only — scale is arbitrary)",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (name, graph) in graphs
    certificate = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        graph,
        mixed_problem;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    )

    n = PCC.n_nodes(graph)
    xs, ys = sublevel_boundary(certificate)
    plot!(
        right,
        xs,
        ys;
        label = "$name, $n node$(n == 1 ? "" : "s") — rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

right

figure = plot(left, right; layout = (1, 2), size = (1100, 620))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
