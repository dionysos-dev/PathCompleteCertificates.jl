# # Optimal control: bounding the value function
#
# The value-function upper bound of [ninite2026path](@cite), for a switched
# system **with an input**: the mode is adversarial, the input is ours. The
# certificate carries both the bound and a state-feedback gain per node.

import PathCompleteCertificates as PCC
import Clarabel
import JuMP
using Random
using Plots

# A rotation and a diagonal contraction, with the same input matrix on both
# modes, and the usual quadratic stage cost ``x^\top Q x + u^\top R u``.

A = [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]]
B = [[1.0; 0.0;;], [1.0; 0.0;;]]

Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]

# !!! warning "One solver setting is required here"
#     Clarabel errors on this model with its chordal decomposition enabled — the
#     default — raising `MethodError: no method matching
#     getindex(::OrderedSet{Int64}, ::Int64)` from its decomposition pass. That
#     is a Clarabel bug rather than a property of the problem, and disabling the
#     pass avoids it.
#
#     Do not reach for Mosek instead: an example that needs a licence cannot be
#     evaluated. SCS is not an alternative either — it aborts inside its
#     log-determinant cone on this objective.

OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)

system = PCC.switched_system(A, B)
problem = PCC.OptimalControlProblem(system, Q, R)

# Optimal control requires a **complete** graph, not merely a path-complete one:
# the bound is read off the plain minimum of Corollary III.3.

graph = PCC.de_bruijn(1, 2; orientation = :complete)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate)

# One gain per node, each mapping a state to an input.

certificate.gains

# The bound itself is a **function of the state**, and `certificate(x)`
# evaluates it.

x = [1.0, 1.0]
certificate(x)

# !!! danger "`objective` is not the bound"
#     `objective` is the log-determinant volume heuristic that selects among
#     feasible certificates. It is a solver diagnostic, routinely negative,
#     whereas the value function is nonnegative whenever ``Q, R \succ 0``.

certificate.objective

# ## The policy, run
#
# `simulate` closes the loop: at each step it draws an admissible mode, applies
# the gain sitting on the node the certificate graph is currently in, and
# advances that node along the mode observed. The gains are **not** a memoryless
# `u(x)` — which node you are in is part of the state of the controller.

run = PCC.simulate(certificate, [3.0, -2.0], 25; rng = MersenneTwister(1))

visited = PCC.states(run)
values = [certificate(state) for state in visited]

# The bound is a minimum of quadratics, one per node, so it is homogeneous of
# degree 2 and its level sets are scalings of a single curve — the same trick
# [The two axes, drawn](@ref) uses. Strictly that curve is a *union* of two
# ellipses, one per node, and the minimising node does change around it; on this
# system the two are close enough that the kinks are not visible.

angles = range(0, 2pi; length = 721)
unit = [certificate([cos(a), sin(a)])^(-1 / 2) for a in angles]

level_set(value) =
    (sqrt(value) .* unit .* cos.(angles), sqrt(value) .* unit .* sin.(angles))

plane = plot(;
    aspect_ratio = :equal,
    framestyle = :origin,
    legend = :outerbottom,
    title = "the run never leaves the set it starts in",
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
    title = "and never back out",
)

plot(plane, descent; layout = (1, 2), size = (900, 460))

# The dashed curve is the level set of the bound through the initial state. The
# run stays inside it for good, and the right panel is why: the bound falls at
# every step, because the edge inequality makes each transition spend at least
# the stage cost.
#
# That monotonicity is what makes the bound a bound — and unlike the single run
# drawn here, it holds for *every* admissible switching sequence.
