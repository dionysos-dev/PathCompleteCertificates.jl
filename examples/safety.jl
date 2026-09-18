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

# ============================================================
# Build the switched system and safety problem
# ============================================================

# ============================================================
# De Bruijn graphs
# ============================================================

graph1 = PCC.de_bruijn(1, 2; orientation = :complete)
graph2 = PCC.de_bruijn(2, 2; orientation = :complete)

# ============================================================
# Compute path-complete barrier certificates
# ============================================================

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)
res = PCC.safety_certificate(PCC.QuadraticTemplate, graph1, problem; optimizer = OPTIMIZER)

x = [1.0, 4.0]
common = PCC.CoBF_complete(res.P, x)
println("Common barrier function value at [1.0, 4.0]: ", common)
observer_graph, states = PCC.observer_graph(graph1)
println("Observer graph: ", states)
common_2 = PCC.CoBF(res.P, states, x)
println("Common barrier function value at [1.0, 4.0]: ", common_2)
