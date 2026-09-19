# This example illustrates the upper-bound construction for the value function
# of a switched linear control system.
#
# Reference example:
# https://github.com/lninite/PathCompleteControl.jl/blob/main/experiments/2D_value_function.jl
#
#     julia --project=test examples/optimal_control.jl

import PathCompleteCertificates as PCC
import Clarabel
import JuMP

const A1 = [
    0.0 1.0;
    -1.0 0.0
]

const A2 = [
    -0.1 0.0;
    0.0 -0.95
]

const A = [A1, A2]
const B1 = [1.0; 0.0;;]
const B = [B1, B1]

const Q = [
    1.0 0.0;
    0.0 1.0
]
const R = [1.0;;]

# Clarabel errors on this model with its chordal decomposition enabled (the
# default) -- `MethodError: no method matching getindex(::OrderedSet{Int64},
# ::Int64)` out of its decomposition pass. That is a Clarabel bug rather than a
# property of the problem, and one setting avoids it. With the setting it
# solves to OPTIMAL at De Bruijn orders 1-3, and the resulting gains satisfy
# the Bellman inequality with a positive margin -- `test/optimal_control.jl`
# checks that directly rather than trusting the status.
#
# Do not reach for Mosek here: an example that needs a licence cannot be
# evaluated. SCS is not an alternative either -- it aborts inside its
# log-determinant cone on this objective.
const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)

# Build the switched system and optimal-control problem

system = PCC.switched_system(A, B)
problem = PCC.OptimalControlProblem(system, Q, R)

# Compute the upper bound on the value function

graph = PCC.de_bruijn(1, 2; orientation = :complete)
result = PCC.optimal_control_certificate(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
)

# `objective` is the log-determinant volume heuristic, not the value-function
# bound -- the bound is `common` below, and it is a function of the state.
println("Optimization objective: $(result.details.objective)")
println("Feasible certificate: $(result.feasible)")
println("State-feedback gains: $(result.details.gains)")

# Evaluate the common upper bound at one state
x = [1.0, 1.0]
common_value = PCC.common(PCC.QuadraticTemplate(), graph, problem, PCC.functions(result), x)
println("Common upper bound value at x = $x: $common_value")
