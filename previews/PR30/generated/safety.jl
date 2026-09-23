import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)

graph1 = PCC.de_bruijn(1, 2; orientation = :complete)
graph2 = PCC.de_bruijn(8, 2; orientation = :co_complete)

PCC.n_nodes(graph1), PCC.n_nodes(graph2)

certificate1 = PCC.certify(PCC.QuadraticTemplate(), graph1, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate1), certificate1.margin

certificate2 = PCC.certify(PCC.QuadraticTemplate(), graph2, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate2), certificate2.margin

x = [1.0, 1.0]
certificate1(x), certificate2(x)

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
