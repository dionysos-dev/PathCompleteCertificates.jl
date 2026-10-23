# # Piecewise semi-ellipsoids: a template from SetProg
#
# SetProg families are accepted directly by PCC. Their stability inequality
# is modeled as the inclusion `(A / rate) * S_source ⊆ S_destination`.
# This example compares polynomial and piecewise set families.

import PathCompleteCertificates as PCC
import Clarabel, HiGHS, JuMP
using SetProg, SumOfSquares
using DynamicPolynomials
using LinearAlgebra
using Plots

const OPTIMIZER = Clarabel.Optimizer

# The rotation and shear of the other examples, on the one-node graph, so that
# the rates differ only by the template.

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))
graph = PCC.common_graph(problem.system)

bound(template) =
    PCC.jsr_bound(template, graph, problem; optimizer = OPTIMIZER, rtol = 1e-3)

# A partition is given by a polytope with the origin in its interior; its
# pieces are the cones over its facets. The polytope is built with Polyhedra on
# a linear programming solver, which SetProg uses on the pieces; HiGHS is a
# simplex solver.

LIBRARY = Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)

polygon(normals) = polyhedron(hrep([HalfSpace(a, norm(a)) for a in normals]), LIBRARY)

octagon = polygon([[2, 1], [1, 2], [-1, 2], [-2, 1], [-2, -1], [-1, -2], [1, -2], [2, -1]])

# ## Three homogeneous set families

using SumOfSquares
@polyvar x[1:2]
families = [
    ("quadratic", PCC.QuadraticTemplate()),
    ("degree 4", PCC.SumOfSquaresTemplate(2, x)),
    ("polyhedral", Polytope(; symmetric = true, piecewise = octagon)),
]
[(name, round(bound(family).rate; digits = 4)) for (name, family) in families]

# ## The piecewise semi-ellipsoid
#
# `Ellipsoid(symmetric = true, piecewise = P)` is a function quadratic on each
# cone of `P` and continuous across them; no other template gives it.
# Refining the partition cannot increase the rate, since a function quadratic
# on each cone of a partition is quadratic on each cone of a finer one.

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
    (name, bound(Ellipsoid(; symmetric = true, piecewise = P))) for (name, P) in partitions
]

[
    (name, nhalfspaces(P), round(certificate.rate; digits = 4)) for
    ((name, P), (_, certificate)) in zip(partitions, piecewise)
]

# On the four cones of the square the piecewise function certifies the rate of
# the plain ellipsoid; the octagon's eight cones improve on it, and sixteen
# cones of degree two give a lower rate than the polynomial of degree four
# above.

# ## Drawing it
#
# The sublevel set ``\{x : V(x) \le 1\}`` of each function, normalised as in
# [Templates and graphs: the two axes](@ref). The piecewise one is a union of
# arcs of ellipses, meeting along the rays of the partition.

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
