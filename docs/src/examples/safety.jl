# # Safety: a barrier certificate
#
# The path-complete barrier functions of [anand2024barrier](@cite): one
# function per node, negative on the initial set, positive on the unsafe set,
# and non-increasing along every edge, so that the region they cut out is
# invariant, contains the initial set and never reaches the unsafe one.

import PathCompleteCertificates as PCC
import Clarabel
using Plots

const OPTIMIZER = Clarabel.Optimizer

# Two modes on the plane, from the paper.

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

INITIAL_RADIUS = 4.0
UNSAFE_RADIUS = 6.0

# Both sets are given in homogeneous coordinates, as
# ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``: here ``\|x\| \le 4`` to start from and
# ``\|x\| \ge 6`` to avoid.

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 INITIAL_RADIUS^2]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -UNSAFE_RADIUS^2]

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)

graph = PCC.de_bruijn(1, 2)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate), certificate.margin

# `margin` is how strictly the barrier separates the two sets. The edge
# inequality itself is non-strict, since a strict one would collapse around
# any cycle and every path-complete graph has one; the strictness sits on the
# separation instead.

# ## Drawing it
#
# A barrier is quadratic in ``[x; 1]``, not homogeneous in ``x``, so its zero
# set is drawn as a contour on a grid.

circle(radius) = (
    radius .* cos.(range(0, 2pi; length = 400)),
    radius .* sin.(range(0, 2pi; length = 400)),
)

figure = plot(;
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
    title = "a path-complete barrier certificate",
    size = (760, 780),
)

plot!(figure, circle(INITIAL_RADIUS)...; lw = 2, ls = :dash, label = "initial set ‖x‖ ≤ 4")
plot!(figure, circle(UNSAFE_RADIUS)...; lw = 2, ls = :dash, label = "unsafe set ‖x‖ ≥ 6")

grid = range(-8, 8; length = 400)
values = [certificate([x, y]) for y in grid, x in grid]

contour!(
    figure,
    grid,
    grid,
    values;
    levels = [0.0],
    lw = 2,
    linecolor = :black,
    colorbar = false,
)

## `contour!` adds no legend entry of its own.
plot!(figure, [NaN], [NaN]; lw = 2, color = :black, label = "barrier, B(x) = 0")

figure

# The solid curve is ``\{x : B(x) = 0\}``, where ``B`` is the common barrier
# the graph and template induce; `certificate(x)` evaluates it. ``B < 0``
# inside, so the region it encloses contains the initial set, is invariant
# under both modes, and never reaches the unsafe set. That is a certificate,
# not a sampled check: the inequality holds for every state in the region and
# every mode.

# !!! note "Safety is quadratic-only for now"
#     Only [`QuadraticTemplate`](@ref) is wired up for the barrier inequality;
#     see [What works with what](@ref).
