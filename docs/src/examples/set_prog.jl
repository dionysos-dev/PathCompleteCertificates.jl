# # Try a richer template
#
# [Bound the joint spectral radius of my system](@ref) proved stability with a
# bigger graph. This page keeps the common graph and changes the template
# instead: a sum of squares of degree 4 proves stability where a quadratic form
# cannot. [Choosing a template](@ref) lists the templates, and here they are
# compared on one system, including SetProg families passed directly.

using PathCompleteCertificates
import Clarabel, HiGHS, JuMP
import LinearAlgebra
import SetProg, SumOfSquares
using Plots

const OPTIMIZER = Clarabel.Optimizer
nothing #hide

# ## The system
#
# The rotation and the shear of
# [Bound the joint spectral radius of my system](@ref), on the common graph:
# every difference below comes from the template.

A = [0.75 * [0.0 1.0; -1.0 0.0], 0.75 * [1.0 1.0; 0.0 1.0]]
system = switched_system(A)
problem = StabilityProblem(system)
graph = common_graph(system)

certified(template) = certify(template, graph, problem; optimizer = OPTIMIZER, rtol = 1e-4)
nothing #hide

# ## Five templates
#
# The quadratic forms, the sums of squares of degree 4 and 6, and two SetProg
# families passed directly: a function quadratic on each cone of a partition,
# and one linear on each. [`PiecewiseQuadraticTemplate`](@ref) and
# [`PiecewiseLinearTemplate`](@ref) build the same families. The partition is
# given by an octagon, whose cones are those over its facets. The octagon is
# built with Polyhedra, on a linear programming solver.

LIBRARY = SetProg.Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)
normals = [[2, 1], [1, 2], [-1, 2], [-2, 1], [-2, -1], [-1, -2], [1, -2], [2, -1]]
octagon = SetProg.polyhedron(
    SetProg.hrep([SetProg.HalfSpace(a, LinearAlgebra.norm(a)) for a in normals]),
    LIBRARY,
)

templates = [
    "quadratic" => QuadraticTemplate(),
    "piecewise quadratic, octagon" =>
        SetProg.Ellipsoid(; symmetric = true, piecewise = octagon),
    "piecewise linear, octagon" =>
        SetProg.Polytope(; symmetric = true, piecewise = octagon),
    "sum of squares, degree 4" => SumOfSquaresTemplate(2),
    "sum of squares, degree 6" => SumOfSquaresTemplate(3),
]
fits = [name => certified(template) for (name, template) in templates]

[name => certificate.rate for (name, certificate) in fits]

# On this system, the sums of squares go below one: on a single node, they
# prove what the quadratic form cannot, at the price of larger semidefinite
# programs, with more variables at each degree. The piecewise families do not,
# and the piecewise linear one gives a higher rate than the quadratic form: the
# best template depends on the system.

# ## The certificates, drawn
#
# On the left, the set ``\{x : V(x) \le 1\}`` of each certificate, scaled to
# the same size: the shape each template allows. On the right, the rates,
# against the stability threshold and the joint spectral radius, the rate of
# the cycle found in [Improve my bound](@ref):

jsr = maximum(abs, LinearAlgebra.eigvals(A[1] * A[2]^4))^(1 / 5)

#-

directions = [[cos(t), sin(t)] for t in range(0, 2pi; length = 721)]

left = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the sets V ≤ 1",
)
for (name, certificate) in fits
    δ = PathCompleteCertificates.homogeneity_degree(get_template(certificate))
    points = [d ./ certificate(d)^(1 / δ) for d in directions]
    radius = maximum(LinearAlgebra.norm, points)
    plot!(left, first.(points) ./ radius, last.(points) ./ radius; lw = 2, label = name)
end

bounds = [certificate.rate for (_, certificate) in fits]
right = bar(
    1:5,
    bounds;
    color = 1:5,
    label = "",
    legend = :topright,
    ylims = (0.9, 1.12),
    xticks = (1:5, ["quad.", "pw quad.", "pw lin.", "SOS 4", "SOS 6"]),
    ylabel = "rate",
    title = "the rates",
)
hline!(right, [1.0]; color = :red, ls = :dot, lw = 2, label = "stability threshold")
hline!(right, [jsr]; color = :black, ls = :dash, lw = 2, label = "joint spectral radius")

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

# ## What it proves
#
# The rate of the sum of squares of degree 6 is about 0.3% above the joint
# spectral radius:

last(bounds) / jsr

# The graph and the template are the two choices of a certificate (see
# [How a certificate works](@ref)): a bigger graph, a richer template, or both.
