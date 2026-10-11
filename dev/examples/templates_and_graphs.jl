# # Templates and graphs: the two axes
#
# A certificate is a template and a graph. This example moves one while
# holding the other: one graph under three templates, then one template over
# four graphs, and finally a third template that reaches past degree two.
#
# Each panel shows the sublevel set ``\{x : V(x) \le 1\}`` of the common
# function, which is what `certificate(x)` evaluates.

import PathCompleteCertificates as PCC
import Clarabel
using HybridSystems
using SumOfSquares, DynamicPolynomials
using Plots

const OPTIMIZER = Clarabel.Optimizer

# Every node function is homogeneous of degree ``d`` =
# [`homogeneity_degree`](@ref), and so is the common function built from them,
# so the radius of the sublevel set in direction ``u`` is ``V(u)^{-1/d}``. The
# same three lines draw every template.

function sublevel_boundary(certificate; samples = 721)
    degree = PCC.homogeneity_degree(PCC.template(certificate))
    angles = range(0, 2pi; length = samples)
    radii = [certificate([cos(a), sin(a)])^(-1 / degree) for a in angles]
    radii ./= maximum(radii)

    return radii .* cos.(angles), radii .* sin.(angles)
end

# !!! warning "Only the shape is comparable"
#     A certificate is determined up to scale, and each template pins that
#     scale differently, so the sets are drawn normalised. The quality of a
#     certificate is its **rate**, which is in the legend.

# ## One graph, three templates
#
# One mode, a rotation scaled by `0.9`, on a single self-loop. Its joint
# spectral radius is `0.9`, and the templates disagree about how close they
# get: a rotation is exactly quadratically stable, badly approximated by a
# polytope with fixed facets, and well approximated once the facets are free.

THETA = pi / 3
ROTATION = [0.9 * [cos(THETA) -sin(THETA); sin(THETA) cos(THETA)]]

rotation_graph = PCC.de_bruijn(1, 1)
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
    title = "one graph, three templates",
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
        label = "$name, rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

left

# ## One template, four graphs
#
# A rotation and a shear. One quadratic function for the whole system is
# conservative; letting the certificate remember the last ``k`` modes, with
# the De Bruijn graph of order ``k``, is less so. The sublevel sets are unions
# of ellipses, non-convex and richer with memory: a path-complete Lyapunov
# function is a common one built from minima and maxima
# ([philippe2017path](@cite)).

MIXED = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
mixed_problem = PCC.StabilityProblem(PCC.switched_system(MIXED))

graphs = [("no memory", PCC.common_graph(mixed_problem.system))]
for order in 1:3
    push!(graphs, ("memory $order", PCC.de_bruijn(order, 2)))
end

right = plot(;
    title = "one template, four graphs",
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
        label = "$name, $n node$(n == 1 ? "" : "s"), rate $(round(certificate.rate; digits = 3))",
        lw = 2,
    )
end

plot(left, right; layout = (1, 2), size = (1100, 620))

# The template decides the shape of the certificate and how conservative it
# is; the graph decides how much history it may use. The rates are ordered
# along each axis; the sets are not nested, since a certificate is only
# determined up to scale.

# ## A third template: sums of squares
#
# [`SumOfSquaresTemplate`](@ref) raises the degree of the node functions
# instead of the memory of the graph ([parrilo2008approximation](@cite)); it is
# behind a package extension, loaded with SumOfSquares, and the polynomial
# variables are created once and shared by every node. Degree 2 is exactly the
# quadratic template; degree 4 bulges where the dynamics need room. The two
# axes compose: enriching the template and enriching the graph are alternative
# routes, and doing both is better than either.

@polyvar x[1:2]

bound(template, graph) =
    PCC.jsr_bound(template, graph, mixed_problem; optimizer = OPTIMIZER, rtol = 1e-4).rate

one_node = PCC.common_graph(mixed_problem.system)
two_nodes = PCC.de_bruijn(1, 2)

[
    ("quadratic, 1 node", bound(PCC.QuadraticTemplate(), one_node)),
    ("degree 4, 1 node", bound(PCC.SumOfSquaresTemplate(2, x), one_node)),
    ("quadratic, 2 nodes", bound(PCC.QuadraticTemplate(), two_nodes)),
    ("degree 4, 2 nodes", bound(PCC.SumOfSquaresTemplate(2, x), two_nodes)),
]
