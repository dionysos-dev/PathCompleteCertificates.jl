# Building switched linear systems.
#
#     julia --project=test examples/switched_systems.jl

import PathCompleteCertificates as PCC
import HybridSystems as HS
import MathematicalSystems as MS

# A two-mode system on the plane: one mode contracts along y, the other along x.
# Neither is stable on its own under arbitrary switching, which is what makes
# switched systems interesting.
A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]

system = PCC.switched_system(A)

println("modes       : ", HS.ntransitions(system.automaton))
println("A           : ", PCC.mode_matrices(system))
println("has input   : ", PCC.has_input(system))

# --- with a control input -------------------------------------------------
# x⁺ = A_σ x + B_σ u. The mode is chosen by the environment; the input is ours.

B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]
controlled = PCC.switched_system(A, B)

Amat, Bmat = PCC.mode_matrices(controlled)
println("\nhas input   : ", PCC.has_input(controlled))
println("B₂          : ", Bmat[2])

# The return value is a HybridSystem, so anything written against that
# vocabulary accepts it unchanged -- and the alias names the parametrisation.
println("a HybridSystem : ", controlled isa HS.HybridSystem)
println("the alias      : ", controlled isa PCC.SwitchedLinearControlSystem)

# --- where the matrices actually live -------------------------------------
# Not on the modes. One discrete state, one self-loop per mode, and the
# dynamics on the transitions keyed by event. That is why mode_matrices exists.

println("\ndiscrete states : ", HS.nstates(controlled.automaton))
println("transitions     : ", HS.ntransitions(controlled.automaton))
println("mode 1 dynamics : ", typeof(HS.mode(controlled, 1)))

# --- restricting the switching --------------------------------------------
# Mode 2 may not follow mode 2.

g = HS.GraphAutomaton(2)
HS.add_transition!(g, 1, 1, 1)
HS.add_transition!(g, 1, 2, 2)
HS.add_transition!(g, 2, 1, 1)

constrained = PCC.switched_system(A, B; automaton = g)
println(
    "\nconstrained: ",
    HS.nstates(constrained.automaton),
    " states, ",
    HS.ntransitions(constrained.automaton),
    " transitions",
)
