import PathCompleteCertificates as PCC
import MathematicalSystems as MS

# A two-mode system on the plane: one mode contracts along y, the other along x.
# Neither is stable on its own under arbitrary switching, which is what makes
# switched systems interesting.
A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]

system = PCC.SwitchedLinearSystem(A)

println("modes      : ", PCC.nmodes(system))
println("state dim  : ", MS.statedim(system))
println("A₁         : ", MS.state_matrix(system, 1))
println("controlled : ", MS.iscontrolled(system))

# --- with a control input -------------------------------------------------
# x⁺ = A_σ x + B_σ u. The mode is chosen by the environment; the input is ours.

B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]
controlled = PCC.SwitchedLinearControlSystem(A, B)

println("\ncontrolled : ", MS.iscontrolled(controlled))
println("input dim  : ", MS.inputdim(controlled))
println("B₂         : ", MS.input_matrix(controlled, 2))

# The accessors are MathematicalSystems generics, so anything written against
# that vocabulary works unchanged:
println("linear     : ", MS.islinear(controlled))
println("noisy      : ", MS.isnoisy(controlled))

# --- restricting the switching --------------------------------------------
# `constraint` holds a labelled digraph saying which mode sequences the plant
# can produce. `nothing` means every sequence is possible.

println("\nunconstrained: ", PCC.constraint(system) === nothing)

# --- interop with HybridSystems -------------------------------------------
# Loading HybridSystems activates the conversion extension. The package itself
# does not depend on it.

import HybridSystems as HS

hs = HS.HybridSystem(controlled)
println(
    "\nas a HybridSystem : ",
    HS.nstates(hs.automaton),
    " discrete state, ",
    HS.ntransitions(hs.automaton),
    " transitions",
)

back = PCC.SwitchedLinearControlSystem(hs)
println(
    "round trip exact   : ",
    MS.state_matrix(back, 1) == A[1] && MS.input_matrix(back, 1) == B[1],
)
