import PathCompleteCertificates as PCC
import Clarabel
import JuMP

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

graph = PCC.de_bruijn(1, 2; orientation = :complete)

certificate = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate)

certificate.gains

x = [1.0, 1.0]
certificate(x)

certificate.objective

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
