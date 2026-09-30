# # Switched systems: the four kinds
#
# Two independent questions decide which kind of switched system you have: does
# the plant choose freely between modes, and is there a continuous input we
# control? Neither implies the other, so there are four combinations and
# [`switched_system`](@ref) builds all of them.

import PathCompleteCertificates as PCC
import HybridSystems as HS

# Two modes on the plane: one contracts along `y`, the other along `x`. Neither
# is stable on its own under arbitrary switching, which is what makes the
# switched case interesting.

A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

# Switching can also be *constrained*. This automaton says mode 2 may not follow
# mode 2 — it is over the same alphabet as the system, and describes which
# switching sequences the plant can actually produce.

constraint = HS.GraphAutomaton(2)
HS.add_transition!(constraint, 1, 1, 1)
HS.add_transition!(constraint, 1, 2, 2)
HS.add_transition!(constraint, 2, 1, 1)

# ## The four combinations

describe(system) = (
    input = PCC.has_input(system),
    states = HS.nstates(system.automaton),
    transitions = HS.ntransitions(system.automaton),
)

# ``x^+ = A_\sigma x``, any switching sequence:

describe(PCC.switched_system(A))

# ``x^+ = A_\sigma x + B_\sigma u``, any sequence. This is the robust
# optimal-control setting: the mode is adversarial, the input is ours.

describe(PCC.switched_system(A, B))

# ``x^+ = A_\sigma x``, but only the sequences the automaton admits:

describe(PCC.switched_system(A; automaton = constraint))

# And both at once:

describe(PCC.switched_system(A, B; automaton = constraint))

# ## Reading the dynamics back
#
# The matrices live on the *transitions*, keyed by mode; the modes themselves
# carry no dynamics at all. That is why these accessors exist rather than
# reaching into the fields.

controlled = PCC.switched_system(A, B)

PCC.mode_matrices(controlled)[1] == A[1]

#-

PCC.input_matrices(controlled)[2] == B[2]

# A system without an input returns `A` alone, so a caller can branch on what it
# gets back rather than on the system's type parameters.

PCC.mode_matrices(PCC.switched_system(A)) == A

# !!! note "Two automata, easily confused"
#     `system.automaton` above constrains which switching sequences the *plant*
#     can produce. The path-complete graph you pass to a certificate is a
#     different object that happens to share its type. Both are a
#     `GraphAutomaton`, so nothing stops you swapping them by accident — the
#     argument name says which is wanted.
