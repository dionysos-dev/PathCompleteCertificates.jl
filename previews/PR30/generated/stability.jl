import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

A = [[0.5 0.0; 0.0 0.25]]

graph = PCC.de_bruijn(1, 1; orientation = :complete)
problem = PCC.StabilityProblem(PCC.switched_system(A))

result = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-2,
)

result.rate

V = PCC.functions(result)
length(V), V[1]([1.0, 1.0])

x = [1.0, 1.0]
PCC.common(PCC.QuadraticTemplate(), graph, problem, PCC.functions(result), x)

result(x)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
