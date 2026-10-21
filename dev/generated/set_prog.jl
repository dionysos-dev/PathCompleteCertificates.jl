import PathCompleteCertificates as PCC
import Clarabel, HiGHS, JuMP
using SetProg, SumOfSquares
using DynamicPolynomials
using LinearAlgebra
using Plots

const OPTIMIZER = Clarabel.Optimizer

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))
graph = PCC.common_graph(problem.system)

bound(template) =
    PCC.jsr_bound(template, graph, problem; optimizer = OPTIMIZER, rtol = 1e-3)

LIBRARY = Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)

polygon(normals) = polyhedron(hrep([HalfSpace(a, norm(a)) for a in normals]), LIBRARY)

octagon = polygon([[2, 1], [1, 2], [-1, 2], [-2, 1], [-2, -1], [-1, -2], [1, -2], [2, -1]])

@polyvar x[1:2]

pairs = [
    (
        "quadratic",
        PCC.QuadraticTemplate(),
        PCC.SetProgTemplate(Ellipsoid(; symmetric = true)),
    ),
    (
        "sum of squares, degree 4",
        PCC.SumOfSquaresTemplate(2, x),
        PCC.SetProgTemplate(PolySet(; symmetric = true, degree = 4, variables = x)),
    ),
    (
        "free facets, 4 cones",
        PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(1)]),
        PCC.SetProgTemplate(Polytope(; symmetric = true, piecewise = octagon)),
    ),
]

[
    (name, round(bound(ours).rate; digits = 4), round(bound(theirs).rate; digits = 4)) for
    (name, ours, theirs) in pairs
]

square = polygon([[1, 0], [0, 1], [-1, 0], [0, -1]])
sixteen = polygon([
    [1, 0],
    [2, 1],
    [1, 1],
    [1, 2],
    [0, 1],
    [-1, 2],
    [-1, 1],
    [-2, 1],
    [-1, 0],
    [-2, -1],
    [-1, -1],
    [-1, -2],
    [0, -1],
    [1, -2],
    [1, -1],
    [2, -1],
])

partitions = [("square", square), ("octagon", octagon), ("16-gon", sixteen)]

piecewise = [
    (name, bound(PCC.SetProgTemplate(Ellipsoid(; symmetric = true, piecewise = P)))) for
    (name, P) in partitions
]

[
    (name, nhalfspaces(P), round(certificate.rate; digits = 4)) for
    ((name, P), (_, certificate)) in zip(partitions, piecewise)
]

function sublevel_boundary(certificate; samples = 721)
    degree = PCC.homogeneity_degree(PCC.template(certificate))
    angles = range(0, 2pi; length = samples)
    radii = [certificate([cos(a), sin(a)])^(-1 / degree) for a in angles]
    radii ./= maximum(radii)

    return radii .* cos.(angles), radii .* sin.(angles)
end

figure = plot(;
    title = "one node, three partitions",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (name, certificate) in piecewise
    xs, ys = sublevel_boundary(certificate)
    plot!(
        figure,
        xs,
        ys;
        label = "$name, rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

figure

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
