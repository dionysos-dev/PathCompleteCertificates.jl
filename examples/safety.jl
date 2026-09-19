# This example illustrates the path-complete barrier function construction
# presented in the following paper:
# M. Anand, R. Jungers, M. Zamani, and F. Allgöwer, 
# "Path-Complete Barrier Functions for Safety of Switched Linear Systems", CDC 2024
#
#     julia --project=test examples/safety.jl

import PathCompleteCertificates as PCC
import Clarabel

const A1 = [
    0.7 0.77;
    -0.49 0.84
]

const A2 = [
    0.7 0.77;
    -0.49 0.56
]

const A = [A1, A2]

# Initial set: x'x <= 16
const S0 = [
    -1.0 0.0 0.0;
    0.0 -1.0 0.0;
    0.0 0.0 16.0
]

# Unsafe set: x'x >= 36
const Su = [
    1.0 0.0 0.0;
    0.0 1.0 0.0;
    0.0 0.0 -36.0
]

const OPTIMIZER = Clarabel.Optimizer

# Build the switched system and safety problem

# De Bruijn graphs

graph1 = PCC.de_bruijn(1, 2; orientation = :complete)
graph2 = PCC.de_bruijn(8, 2; orientation = :co_complete)

# Compute path-complete barrier certificates

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)

x = [1.0, 1.0]

res =
    PCC.safety_certificate(PCC.QuadraticTemplate(), graph1, problem; optimizer = OPTIMIZER)
common_value = PCC.common(PCC.QuadraticTemplate(), graph1, problem, PCC.functions(res), x)
println("Common barrier function value at x = $x: $common_value for graph 1")

res2 =
    PCC.safety_certificate(PCC.QuadraticTemplate(), graph2, problem; optimizer = OPTIMIZER)
common_value2 = PCC.common(PCC.QuadraticTemplate(), graph2, problem, PCC.functions(res2), x)
println("Common barrier function value at x = $x: $common_value2 for graph 2")
