# This example illustrates path-complete Lyapunov functions for a switched
# linear system.
#
#     julia --project=test examples/stability.jl

import PathCompleteCertificates as PCC
import Clarabel

const A1 = [
    0.5 0.0;
    0.0 0.25
]

const A = [A1]
const OPTIMIZER = Clarabel.Optimizer

# Build the switched system and stability problem

graph = PCC.de_bruijn(1, 1; orientation = :complete)
problem = PCC.StabilityProblem(PCC.switched_system(A))

# Compute an upper bound on the JSR and the corresponding node Lyapunov functions

result = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-2,
)
println("Joint spectral radius upper bound: $(result.bound)")

x = [1.0, 1.0]
common_value = PCC.common(PCC.QuadraticTemplate(), graph, problem, result.V, x)
println("Common Lyapunov function value at x = $x: $common_value")
