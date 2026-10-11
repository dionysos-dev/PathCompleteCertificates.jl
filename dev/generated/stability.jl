import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

A = [[0.5 0.0; 0.0 0.25]]

graph = PCC.de_bruijn(1, 1)
problem = PCC.StabilityProblem(PCC.switched_system(A))

at_six_tenths =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rate = 0.6)
at_four_tenths =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rate = 0.4)

PCC.is_feasible(at_six_tenths), PCC.is_feasible(at_four_tenths)

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
result(x)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
