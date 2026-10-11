import PathCompleteCertificates as PCC
import Clarabel
using Plots

const OPTIMIZER = Clarabel.Optimizer
const TEMPLATE = PCC.QuadraticTemplate()

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

trace = PCC.refine(TEMPLATE, problem; optimizer = OPTIMIZER, depth_max = 4)

sizes = PCC.n_nodes.(PCC.graphs(trace))
bounds = PCC.rates(trace)

collect(zip(sizes, round.(bounds; digits = 5)))

PCC.status(trace)

lower = PCC.jsr_lower_bound.(PCC.certificates(trace))

collect(zip(sizes, round.(lower; digits = 5), round.(bounds; digits = 5)))

turn(angle) = 0.9 .* [cos(angle) -sin(angle); sin(angle) cos(angle)]
rotations = PCC.StabilityProblem(PCC.switched_system([turn(pi / 3), turn(-pi / 3)]))

exact = PCC.refine(TEMPLATE, PCC.de_bruijn(1, 2), rotations; optimizer = OPTIMIZER)

PCC.status(exact), round(PCC.rates(exact)[end]; digits = 6)

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

all(graph -> PCC.is_path_complete(graph, 1:length(A)), PCC.graphs(trace))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
