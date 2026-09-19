# What a path-complete barrier certificate looks like.
#
#     julia --project=examples examples/safety_barrier.jl
#
# Anand, Jungers, Zamani & Allgöwer, CDC 2024: two modes on the plane, every
# trajectory starting in ‖x‖ ≤ 4 must avoid ‖x‖ ≥ 6. The certificate is a
# barrier that is negative on the initial set, positive on the unsafe one, and
# never increases along a transition — so the region it cuts out is invariant,
# and the unsafe set is outside it.

import PathCompleteCertificates as PCC
import Clarabel
using Plots

const OPTIMIZER = Clarabel.Optimizer

const A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
const INITIAL_RADIUS = 4.0
const UNSAFE_RADIUS = 6.0

# Both sets in homogeneous coordinates: {x : [x;1]' S [x;1] ≥ 0}.
const S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 INITIAL_RADIUS^2]
const SU = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -UNSAFE_RADIUS^2]

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, SU)

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

graph = PCC.de_bruijn(1, 2)

certificate =
    PCC.safety_certificate(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate) || error("no barrier found")

# The barrier is affine-quadratic, not homogeneous, so its zero set is not
# star-shaped and the radius trick of `two_axes.jl` does not apply. A contour on
# a grid is the honest way to draw it.
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

# `contour!` adds no legend entry of its own.
plot!(figure, [NaN], [NaN]; lw = 2, color = :black, label = "barrier, B(x) = 0")

output = joinpath(@__DIR__, "safety_barrier.png")
savefig(figure, output)

println(
    "De Bruijn memory 1 (",
    PCC.n_nodes(graph),
    " nodes): separation margin = ",
    round(certificate.margin; sigdigits = 3),
)
println("wrote ", output)
println()
println("The solid curve is {x : B(x) = 0}, where B is the common barrier the")
println("graph and template induce -- `certificate(x)` evaluates it. B < 0 inside,")
println("so the region it encloses contains the initial set, is invariant under")
println("both modes, and never reaches the unsafe set. That is the certificate:")
println("not a simulation, and not a sampled check.")
println()
println("Memory 2 gives the same barrier here -- one mode of memory already")
println("suffices, so the graph axis buys nothing on this instance. It does on")
println("others; see two_axes.jl.")
