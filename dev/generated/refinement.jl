import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra
using Plots
include(joinpath(pkgdir(PCC), "docs", "graph_drawing.jl")) #hide

const TEMPLATE = PCC.QuadraticTemplate()
const OPTIMIZER = Clarabel.Optimizer
nothing #hide

A = [0.75 * [0.0 1.0; -1.0 0.0], 0.75 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))
nothing #hide

trace = PCC.refine(TEMPLATE, problem; optimizer = OPTIMIZER, depth_max = 10)

steps = [
    (PCC.n_nodes(graph), certificate.rate, PCC.jsr_lower_bound(certificate)) for
    (graph, certificate) in zip(PCC.graphs(trace), PCC.certificates(trace))
]

PCC.status(trace)

de_bruijn = [
    (2^k, PCC.certify(TEMPLATE, PCC.de_bruijn(k, 2), problem; optimizer = OPTIMIZER).rate) for k in 0:3
]

left = plot(;
    xlabel = "number of nodes",
    ylabel = "bound on the joint spectral radius",
    legend = :topright,
    ylims = (0.94, 1.07),
    title = "refine against De Bruijn",
)
plot!(
    left,
    first.(steps),
    getindex.(steps, 2);
    marker = :circle,
    lw = 2,
    color = :black,
    label = "refine, upper bound",
)
plot!(
    left,
    first.(steps),
    last.(steps);
    marker = :circle,
    lw = 2,
    ls = :dash,
    color = :black,
    label = "refine, lower bound",
)
plot!(
    left,
    first.(de_bruijn),
    last.(de_bruijn);
    marker = :square,
    lw = 2,
    color = :steelblue,
    label = "De Bruijn, upper bound",
)
hline!(left, [1.0]; color = :red, ls = :dot, label = "stability threshold")

final = last(PCC.certificates(trace))
right = draw_tight_edges(final) #hide

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

slowest = maximum(abs, LinearAlgebra.eigvals(A[1] * A[2]^4))^(1 / 5)
PCC.is_jsr_exact(final), final.rate, slowest

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
