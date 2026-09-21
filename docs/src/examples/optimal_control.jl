# # Optimal control: bounding the value function
#
# The value-function upper bound of [ninite2026path](@cite), for a switched
# system **with an input**: the mode is adversarial, the input is ours. The
# certificate carries both the bound and a state-feedback gain per node.

import PathCompleteCertificates as PCC
import Clarabel
import JuMP

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

certificate = PCC.optimal_control_certificate(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
)

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
