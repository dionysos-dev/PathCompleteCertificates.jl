import PathCompleteCertificates as PCC
import Clarabel, HiGHS, JuMP
import LinearAlgebra
using SetProg, SumOfSquares, DynamicPolynomials
using Plots

const OPTIMIZER = Clarabel.Optimizer
nothing #hide

A = [0.75 * [0.0 1.0; -1.0 0.0], 0.75 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))
graph = PCC.common_graph(problem.system)

certified(template) =
    PCC.certify(template, graph, problem; optimizer = OPTIMIZER, rtol = 1e-4)
nothing #hide

LIBRARY = Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)
normals = [[2, 1], [1, 2], [-1, 2], [-2, 1], [-2, -1], [-1, -2], [1, -2], [2, -1]]
octagon = polyhedron(hrep([HalfSpace(a, LinearAlgebra.norm(a)) for a in normals]), LIBRARY)

@polyvar x[1:2]
templates = [
    "quadratic" => PCC.QuadraticTemplate(),
    "piecewise quadratic, octagon" =>
        Ellipsoid(; symmetric = true, piecewise = octagon),
    "piecewise linear, octagon" => Polytope(; symmetric = true, piecewise = octagon),
    "sum of squares, degree 4" => PCC.SumOfSquaresTemplate(2, x),
    "sum of squares, degree 6" => PCC.SumOfSquaresTemplate(3, x),
]
certificates = [name => certified(template) for (name, template) in templates]

[name => certificate.rate for (name, certificate) in certificates]

directions = [[cos(t), sin(t)] for t in range(0, 2pi; length = 721)]

left = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the sets V ≤ 1",
)
for (name, certificate) in certificates
    p = PCC.homogeneity_degree(PCC.template(certificate))
    points = [d ./ certificate(d)^(1 / p) for d in directions]
    radius = maximum(LinearAlgebra.norm, points)
    plot!(left, first.(points) ./ radius, last.(points) ./ radius; lw = 2, label = name)
end

rates = [certificate.rate for (_, certificate) in certificates]
right = bar(
    1:5,
    rates;
    color = 1:5,
    label = "",
    legend = :topright,
    ylims = (0.9, 1.12),
    xticks = (1:5, ["quad.", "pw quad.", "pw lin.", "SOS 4", "SOS 6"]),
    ylabel = "rate",
    title = "the rates",
)
hline!(right, [1.0]; color = :red, ls = :dot, lw = 2, label = "stability threshold")
hline!(right, [0.976]; color = :black, ls = :dash, lw = 2, label = "joint spectral radius")

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
