import PathCompleteCertificates as PCC
import Clarabel
using HybridSystems
using Plots

const OPTIMIZER = Clarabel.Optimizer
const TEMPLATE = PCC.QuadraticTemplate()

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

seed = GraphAutomaton(1)
add_transition!(seed, 1, 1, 1)
add_transition!(seed, 1, 1, 2)

trace = PCC.refine(
    TEMPLATE,
    seed,
    problem;
    optimizer = OPTIMIZER,
    depth_max = 4,
    lift = PCC.forward_edge_lift,
)

sizes = PCC.n_nodes.(PCC.graphs(trace))
bounds = PCC.rates(trace)

collect(zip(sizes, round.(bounds; digits = 5)))

de_bruijn = map([1, 2]) do order
    graph = PCC.de_bruijn(order, 2)
    certificate = PCC.jsr_bound(TEMPLATE, graph, problem; optimizer = OPTIMIZER)

    return PCC.n_nodes(graph), certificate.rate
end

plot(
    sizes,
    bounds;
    marker = :circle,
    markersize = 5,
    lw = 2,
    label = "refine",
    xlabel = "number of nodes",
    ylabel = "certified rate",
    xticks = sizes,
    legend = :topright,
    title = "the same budget, spent better",
)
plot!(
    first.(de_bruijn),
    last.(de_bruijn);
    marker = :square,
    markersize = 6,
    lw = 2,
    ls = :dash,
    label = "de_bruijn",
)

function sublevel_boundary(certificate; samples = 721)
    degree = PCC.rate_exponent(PCC.template(certificate))
    angles = range(0, 2pi; length = samples)
    radii = [certificate([cos(a), sin(a)])^(-1 / degree) for a in angles]
    radii ./= maximum(radii)

    return radii .* cos.(angles), radii .* sin.(angles)
end

shapes = plot(;
    title = "one ellipse per node, intersected\n(shape only — scale is arbitrary)",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (n, certificate) in zip(sizes, PCC.certificates(trace))
    xs, ys = sublevel_boundary(certificate)
    plot!(shapes, xs, ys; lw = 2, label = "$n node(s)")
end

shapes

PCC.is_co_complete.(PCC.graphs(trace))

all(graph -> PCC.is_path_complete(graph, 1:length(A)), PCC.graphs(trace))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
