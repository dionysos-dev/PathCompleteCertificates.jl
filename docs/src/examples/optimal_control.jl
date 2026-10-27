# # Design a controller robust to switching
#
# The value-function upper bound of [ninite2026path](@cite), for a switched
# system with an input, where the mode is chosen by an adversary and the input
# by the controller. The certificate holds the bound and a state-feedback gain
# per node.

import PathCompleteCertificates as PCC
import Clarabel
import JuMP
using Random
using Plots

# A rotation and a diagonal contraction, with the same input matrix on both
# modes, and the quadratic stage cost ``x^\top Q x + u^\top R u``.

A = [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]]
B = [[1.0; 0.0;;], [1.0; 0.0;;]]

Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]

OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)

system = PCC.switched_system(A, B)
problem = PCC.OptimalControlProblem(system, Q, R)

# The graph must be complete, which is stronger than path-complete, because
# the bound is the minimum of the node functions.

graph = PCC.de_bruijn(1, 2)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate)

# One gain per node, each mapping a state to an input.

certificate.gains

# The bound is a function of the state. A certificate is callable:
# `certificate(x)` evaluates the bound at `x`.

x = [1.0, 1.0]
certificate(x)

# ## The policy, run
#
# `simulate` closes the loop: at each step it draws a mode and applies the gain
# of the node whose function is smallest at the current state. The policy is a
# plain state feedback, piecewise linear.

run = PCC.simulate(certificate, [3.0, -2.0], 25; rng = MersenneTwister(1))

visited = PCC.states(run)
values = [certificate(state) for state in visited]

# The bound is a minimum of quadratics, homogeneous of degree 2, so its level
# sets are scalings of one curve.

angles = range(0, 2pi; length = 721)
unit = [certificate([cos(a), sin(a)])^(-1 / 2) for a in angles]

level_set(value) =
    (sqrt(value) .* unit .* cos.(angles), sqrt(value) .* unit .* sin.(angles))

plane = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "closed-loop run and the initial level set",
)

plot!(
    plane,
    level_set(first(values))...;
    lw = 2,
    ls = :dash,
    color = :grey,
    label = "bound at the initial state",
)

plot!(
    plane,
    first.(visited),
    last.(visited);
    marker = :circle,
    markersize = 3,
    lw = 2,
    label = "closed loop",
)

descent = plot(
    values;
    marker = :circle,
    markersize = 3,
    lw = 2,
    yscale = :log10,
    legend = false,
    xlabel = "step",
    ylabel = "bound at the state",
    title = "bound along the run",
)

plot(plane, descent; layout = (1, 2), size = (900, 460))

# The dashed curve is the level set of the bound through the initial state,
# and the run stays inside it. The right panel shows that the bound decreases
# at every step, by at least the stage cost, as the edge inequality requires.
# The edge inequality holds for every admissible switching sequence, so this
# is true of every run.
