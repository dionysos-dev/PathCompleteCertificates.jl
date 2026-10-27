# # Prove my system safe
#
# A switched system that starts in a disk and must never reach the outside of a
# larger one. No single barrier function proves it; a path-complete barrier on
# two nodes does, as in [anand2024barrier](@cite).
# [How a certificate works](@ref) explains the certificate; this page runs it
# from start to end.

import PathCompleteCertificates as PCC
import Clarabel
import Random
using Plots

const TEMPLATE = PCC.QuadraticTemplate()
const OPTIMIZER = Clarabel.Optimizer
nothing #hide

# ## The system
#
# Two modes on the plane, from [anand2024barrier](@cite). The trajectories
# start in the disk ``\|x\| \le 4`` and must avoid ``\|x\| \ge 6``; both sets
# are given in homogeneous coordinates, as ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``.

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
system = PCC.switched_system(A)

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]
problem = PCC.SafetyProblem(system, S0, Su)
nothing #hide

# ## A single function
#
# On the one-node graph, the certificate is a common barrier function. None
# exists:

PCC.is_feasible(
    PCC.certify(TEMPLATE, PCC.common_graph(system), problem; optimizer = OPTIMIZER),
)

# ## A path-complete graph
#
# The De Bruijn graph of order 1 gives one barrier per node, and a positive
# margin: the system is safe.

graph = PCC.de_bruijn(1, 2)
certificate = PCC.certify(TEMPLATE, graph, problem; optimizer = OPTIMIZER)
PCC.is_feasible(certificate), certificate.margin

# ## The certificate, drawn
#
# On the left, the zero set of each node barrier, and that of their common
# barrier ``B``, here their minimum: the region where ``B < 0`` contains the
# initial set and does not meet the unsafe set. On the right, ``B`` along 100
# random switching sequences from the boundary of the initial set: it never
# increases, so it stays negative and no run reaches the unsafe set.

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
    title = "the zero sets B = 0",
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
plot!(left, [NaN], [NaN]; color = :black, lw = 4, label = "common")
## `contour!` adds no legend entry of its own.
for (a, V) in enumerate(PCC.functions(certificate))
    color = (:darkorange, :purple)[a]
    values = [PCC.node_value(problem, V, [x, y]) for y in grid, x in grid]
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
    ylabel = "B(xₖ)",
    legend = :bottomright,
    title = "B along switching sequences",
)
for run in 1:100
    angle = 2pi * run / 100
    visited = PCC.states(PCC.simulate(system, 4 .* [cos(angle), sin(angle)], 30; rng))
    plot!(
        right,
        0:30,
        certificate.(visited);
        color = :steelblue,
        alpha = 0.3,
        label = run == 1 ? "100 random runs" : "",
    )
end
hline!(right, [0.0]; color = :black, lw = 3, ls = :dash, label = "B = 0")

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

# ## What it proves
#
# The margin is positive, so the region where ``B < 0`` contains the initial
# set, is invariant under every switching sequence, and avoids the unsafe set
# (see [Reading a certificate](@ref)). A finer graph adds nothing here: the
# De Bruijn graph of order 2 certifies the same margin.

PCC.certify(TEMPLATE, PCC.de_bruijn(2, 2), problem; optimizer = OPTIMIZER).margin
