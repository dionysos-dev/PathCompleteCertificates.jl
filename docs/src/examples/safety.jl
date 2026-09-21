# # Safety: a barrier certificate
#
# The path-complete barrier construction of [anand2024barrier](@cite). A barrier
# is negative on the initial set, positive on the unsafe set, and never
# increases along a transition — so the region it cuts out is invariant,
# contains everything the system may start from, and never reaches the unsafe
# set.
#
# This example is the numbers; [`safety_barrier.jl`](@ref "Safety: drawing the barrier")
# draws the resulting set.

import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

# Two modes on the plane, from the paper.

A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

# Both sets are given in **homogeneous coordinates**, as
# ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``. Here the initial set is
# ``\|x\| \le 4`` and the unsafe set is ``\|x\| \ge 6``.

S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]

problem = PCC.SafetyProblem(PCC.switched_system(A), S0, Su)

# ## Two graphs, two aggregations
#
# The orientation of a De Bruijn graph decides which sufficient condition holds,
# and therefore how the node barriers combine: `:complete` aggregates with a
# minimum, `:co_complete` with a maximum.

graph1 = PCC.de_bruijn(1, 2; orientation = :complete)
graph2 = PCC.de_bruijn(8, 2; orientation = :co_complete)

PCC.n_nodes(graph1), PCC.n_nodes(graph2)

# The small graph first.

certificate1 =
    PCC.safety_certificate(PCC.QuadraticTemplate(), graph1, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate1), certificate1.margin

# `margin` is the separation the solver achieved between the barrier and the two
# sets. It is where the *strictness* of the certificate lives: the edge
# inequality itself is non-strict, because making it strict would collapse
# around any cycle to ``0 \ge L\varepsilon`` and every path-complete graph has a
# cycle.
#
# Now a graph with eight modes of memory, 256 nodes, in the opposite
# orientation.

certificate2 =
    PCC.safety_certificate(PCC.QuadraticTemplate(), graph2, problem; optimizer = OPTIMIZER)

PCC.is_feasible(certificate2), certificate2.margin

# Both certify the same system. The barrier each induces is what
# `certificate(x)` evaluates:

x = [1.0, 1.0]
certificate1(x), certificate2(x)

# !!! note "Safety is quadratic-only for now"
#     The barrier is imposed on the homogeneous lift of the dynamics, and only
#     [`QuadraticTemplate`](@ref) is wired up for it. See
#     [What works with what](@ref) — the gap is plumbing, not mathematics.
