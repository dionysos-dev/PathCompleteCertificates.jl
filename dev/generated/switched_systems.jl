import PathCompleteCertificates as PCC
import HybridSystems as HS

A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

constraint = HS.GraphAutomaton(2)
HS.add_transition!(constraint, 1, 1, 1)
HS.add_transition!(constraint, 1, 2, 2)
HS.add_transition!(constraint, 2, 1, 1)

describe(system) = (
    input = PCC.has_input(system),
    states = HS.nstates(system.automaton),
    transitions = HS.ntransitions(system.automaton),
)

describe(PCC.switched_system(A))

describe(PCC.switched_system(A, B))

describe(PCC.switched_system(A; automaton = constraint))

describe(PCC.switched_system(A, B; automaton = constraint))

controlled = PCC.switched_system(A, B)

PCC.mode_matrices(controlled)[1] == A[1]

PCC.input_matrices(controlled)[2] == B[2]

PCC.mode_matrices(PCC.switched_system(A)) == A

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
