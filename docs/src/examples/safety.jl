# # Safety: a barrier certificate
#
# The path-complete barrier construction of [anand2024barrier](@cite). A barrier
# is negative on the initial set, positive on the unsafe set, and never
# increases along a transition — so the region it cuts out is invariant,
# contains everything the system may start from, and never reaches the unsafe
# set.

import PathCompleteCertificates as PCC
import Clarabel
using Plots

const OPTIMIZER = Clarabel.Optimizer

# Two modes on the plane, from the paper.

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

INITIAL_RADIUS = 4.0
UNSAFE_RADIUS = 6.0

# Both sets are given in **homogeneous coordinates**, as
# ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``: here ``\|x\| \le 4`` to start from and
# ``\|x\| \ge 6`` to avoid.

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 INITIAL_RADIUS^2]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -UNSAFE_RADIUS^2]

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)

graph = PCC.de_bruijn(1, 2)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate), certificate.margin

# `margin` is the separation the solver achieved between the barrier and the two
# sets, and it is where the *strictness* lives: the edge inequality itself is
# non-strict, because a strict one collapses around any cycle to
# ``0 \ge L\varepsilon`` and every path-complete graph has a cycle.

# ## Drawing it
#
# The barrier is affine-quadratic, not homogeneous, so its zero set is not
# star-shaped and the radius trick of
# [`two_axes.jl`](@ref "The two axes, drawn") does not apply. A contour on a
# grid is the honest way to draw it.

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

# The solid curve is ``\{x : B(x) = 0\}``, where ``B`` is the common barrier the
# graph and template induce — `certificate(x)` evaluates it. ``B < 0`` inside,
# so the region it encloses contains the initial set, is invariant under both
# modes, and never reaches the unsafe set.
#
# That is a *certificate*, not a simulation and not a sampled check: the
# inequality holds for every state in the region and every mode, not only along
# the trajectories someone happened to draw.

# ## The orientation decides the aggregation
#
# A De Bruijn graph comes in two orientations, and they differ in how the node
# barriers combine: `:complete` aggregates with a minimum, `:co_complete` with a
# maximum ([`common`](@ref) dispatches on it). Here is the other one, with eight
# modes of memory.

dual = PCC.de_bruijn(8, 2; orientation = :co_complete)

PCC.n_nodes(dual)

#-

certificate_dual =
    PCC.certify(PCC.QuadraticTemplate(), dual, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate_dual), certificate_dual.margin

# Both certify the same system, by different routes. Memory buys nothing on this
# instance — one mode already suffices — but it does on others; see
# [The two axes, drawn](@ref).

x = [1.0, 1.0]
certificate(x), certificate_dual(x)

# !!! note "Safety is quadratic-only for now"
#     The barrier is imposed on the homogeneous lift of the dynamics, and only
#     [`QuadraticTemplate`](@ref) is wired up for it. See
#     [What works with what](@ref) — the gap is plumbing, not mathematics.
