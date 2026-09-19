# The four kinds of switched linear system, and how to read one back.
#
# No environment of its own -- run it with the test one, which already has the
# package and its dependencies:
#
#     julia --project=test examples/switched_systems.jl

import PathCompleteCertificates as PCC
import HybridSystems as HS
import MathematicalSystems as MS

# Two modes on the plane: one contracts along y, the other along x. Neither is
# stable on its own under arbitrary switching, which is what makes the switched
# case interesting.
A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

# Mode 2 may not follow mode 2: an automaton over the same alphabet saying which
# switching sequences the plant can actually produce.
constraint = HS.GraphAutomaton(2)
HS.add_transition!(constraint, 1, 1, 1)
HS.add_transition!(constraint, 1, 2, 2)
HS.add_transition!(constraint, 2, 1, 1)

function describe(name, system)
    println("── ", name)
    println("   input        : ", PCC.has_input(system))
    println("   states       : ", HS.nstates(system.automaton))
    println("   transitions  : ", HS.ntransitions(system.automaton))
    return println()
end

# --- the four combinations ------------------------------------------------
# Two independent questions: does the plant choose freely between modes, and is
# there a continuous input we control? Neither implies the other.

#  x⁺ = A_σ x, any sequence
describe("arbitrary switching, no input", PCC.switched_system(A))

#  x⁺ = A_σ x + B_σ u, any sequence -- the robust optimal-control setting: the
#  mode is adversarial, the input is ours
describe("arbitrary switching, with input", PCC.switched_system(A, B))

#  x⁺ = A_σ x, only the sequences the automaton admits
describe("constrained switching, no input", PCC.switched_system(A; automaton = constraint))

#  both
describe(
    "constrained switching, with input",
    PCC.switched_system(A, B; automaton = constraint),
)

# --- reading the dynamics back --------------------------------------------
# The matrices live on the transitions, keyed by mode, and the modes themselves
# carry no dynamics at all -- which is why this accessor exists rather than
# reaching into the fields.

controlled = PCC.switched_system(A, B)
Amat = PCC.mode_matrices(controlled)
Bmat = PCC.input_matrices(controlled)

println("A₁ == A[1] : ", Amat[1] == A[1])
println("B₂ == B[2] : ", Bmat[2] == B[2])
println("mode 1 is  : ", typeof(HS.mode(controlled, 1)))

# A system without an input returns `A` alone, so a caller can branch on what it
# gets back rather than on the system's type parameters.
println("no input   : ", PCC.mode_matrices(PCC.switched_system(A)) == A)
