# # Prove my system safe
#
# A switched system that starts in a disk and must never reach the outside of a
# larger one. No single quadratic barrier function proves it. A path-complete
# barrier certificate on two nodes does, as in [anand2024barrier](@cite).
# [How a certificate works](@ref) explains the certificate, and this page runs it
# from start to end.

using PathCompleteCertificates
import Clarabel
import Random
using Plots

const TEMPLATE = QuadraticTemplate()
const OPTIMIZER = Clarabel.Optimizer
nothing #hide

# ## The system
#
# Two modes on the plane, from [anand2024barrier](@cite). The trajectories
# start in the disk ``X_0 = \{x : \|x\| \le 4\}`` and must avoid
# ``X_u = \{x : \|x\| \ge 6\}``. Both sets are given in homogeneous
# coordinates, as ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``.

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
system = switched_system(A)

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]
problem = SafetyProblem(system, S0, Su)
nothing #hide

# ## A single function
#
# On the common graph, the certificate is a common barrier function. The
# quadratic template finds none:

is_feasible(certify(TEMPLATE, common_graph(system), problem; optimizer = OPTIMIZER))

# ## A path-complete graph
#
# The De Bruijn graph of order 1 gives one barrier per node, and a positive
# margin: the system is safe.

graph = de_bruijn(1, 2)
certificate = certify(TEMPLATE, graph, problem; optimizer = OPTIMIZER)
is_feasible(certificate), certificate.margin

# ## The certificate, drawn
#
# On the left, the zero set of each node function, and that of their common
# certificate ``V``, here their minimum: the set where ``V \le 0`` contains
# ``X_0`` and does not meet ``X_u``. On the right, ``V`` along 100 random
# switching sequences from the boundary of ``X_0``: it never increases, so it
# stays negative and no run reaches ``X_u``.

grid = range(-7, 7; length = 300)
disk(radius) = Shape(
    radius .* cos.(range(0, 2pi; length = 200)),
    radius .* sin.(range(0, 2pi; length = 200)),
)

left = plot(;
    aspect_ratio = :equal,
    framestyle = :box,
    xlims = (-7, 7),
    ylims = (-7, 7),
    legend = :outerbottom,
    title = "the zero sets V = 0",
)
plot!(
    left,
    Shape([-7, 7, 7, -7], [-7, -7, 7, 7]);
    color = :red,
    alpha = 0.2,
    linealpha = 0,
    label = "unsafe set, ‖x‖ ≥ 6",
)
plot!(left, disk(6.0); color = :white, linecolor = :red, label = "")
plot!(left, disk(4.0); color = :green, alpha = 0.3, label = "initial set, ‖x‖ ≤ 4")
contour!(
    left,
    grid,
    grid,
    [certificate([x, y]) for y in grid, x in grid];
    levels = [0.0],
    color = :black,
    lw = 4,
    colorbar = false,
)
## `contour!` adds no legend entry of its own.
plot!(left, [NaN], [NaN]; color = :black, lw = 4, label = "common")
for (a, V) in enumerate(functions(certificate))
    color = (:darkorange, :purple)[a]
    values = [node_value(problem, V, [x, y]) for y in grid, x in grid]
    contour!(
        left,
        grid,
        grid,
        values;
        levels = [0.0],
        color,
        lw = 2,
        ls = :dash,
        colorbar = false,
    )
    plot!(left, [NaN], [NaN]; color, lw = 2, ls = :dash, label = "node $a")
end

rng = Random.MersenneTwister(1)
right = plot(;
    xlabel = "step k",
    ylabel = "V(xₖ)",
    legend = :bottomright,
    title = "V along switching sequences",
)
for run in 1:100
    angle = 2pi * run / 100
    visited = states(simulate(system, 4 .* [cos(angle), sin(angle)], 30; rng))
    plot!(
        right,
        0:30,
        certificate.(visited);
        color = :steelblue,
        alpha = 0.3,
        label = run == 1 ? "100 random runs" : "",
    )
end
hline!(right, [0.0]; color = :black, lw = 3, ls = :dash, label = "V = 0")

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

# ## What it proves
#
# The margin is positive, so the set where ``V \le 0`` contains ``X_0``, is
# invariant under every switching sequence, and avoids ``X_u`` (see
# [How a certificate works](@ref)). A finer graph adds nothing here: the
# De Bruijn graph of order 2 certifies the same margin.

certify(TEMPLATE, de_bruijn(2, 2), problem; optimizer = OPTIMIZER).margin

# ## Other templates
#
# The template is the other choice. A polynomial barrier of degree 4, from
# `SumOfSquaresTemplate(2)`, proves safety on the common graph, where the
# quadratic one does not:

import SumOfSquares

polynomial =
    certify(SumOfSquaresTemplate(2), common_graph(system), problem; optimizer = OPTIMIZER)
is_feasible(polynomial), polynomial.margin

# A piecewise quadratic barrier, ``x^\top P_{s,k} x - 1`` on each cone of a
# partition, also proves it on the De Bruijn graph of order 1. The partition
# here is the square with vertices ``(\pm 1, 0)`` and ``(0, \pm 1)``, whose
# cones are the four quadrants, built with Polyhedra on a linear programming
# solver:

import HiGHS, JuMP, SetProg

library = SetProg.Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)
square = SetProg.polyhedron(SetProg.hrep([1.0 1.0; 1 -1; -1 1; -1 -1], ones(4)), library)
piecewise = certify(
    PiecewiseQuadraticTemplate(fill(square, 2)),
    graph,
    problem;
    optimizer = OPTIMIZER,
)
is_feasible(piecewise), piecewise.margin
