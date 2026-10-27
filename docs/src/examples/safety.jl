# # Prove my system safe
#
# The path-complete barrier functions of [anand2024barrier](@cite): one
# function per node, negative on the initial set, positive on the unsafe set,
# and non-increasing along every edge. The region where the common barrier is
# negative is then invariant, contains the initial set and does not meet the
# unsafe set.

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

# `margin` is the margin by which the barrier separates the two sets. The edge
# inequality has no margin: every lifted map fixes ``[0; 1]``, so a margin
# summed around a cycle would be nonpositive, and every path-complete graph
# has a cycle.

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
# the graph and template induce; calling the certificate, `certificate(x)`,
# evaluates it. ``B < 0``
# inside, so the region it encloses contains the initial set, is invariant
# under arbitrary switching, and does not meet the unsafe set.

# !!! note "Safety is quadratic-only for now"
#     Only [`QuadraticTemplate`](@ref) is wired up for the barrier inequality;
#     see [What works with what](@ref).
