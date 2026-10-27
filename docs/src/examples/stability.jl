# # Bound the joint spectral radius of my system
#
# A switched linear system and a path-complete graph give an upper bound on the
# joint spectral radius, with the node functions that prove it.

import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

# One mode, a diagonal matrix. With a single mode the joint spectral radius is
# the spectral radius, `0.5`.

A = [[0.5 0.0; 0.0 0.25]]

# The De Bruijn graph of order 1 over one mode has a single node and a
# self-loop.

graph = PCC.de_bruijn(1, 1)
problem = PCC.StabilityProblem(PCC.switched_system(A))

# ## One solve at a given rate
#
# Given a `rate`, [`certify`](@ref) asks whether the system contracts at that
# rate on this graph, in this template. It returns a certificate in both
# cases, and [`is_feasible`](@ref) says whether the problem was feasible: here
# at `0.6` and not at `0.4`, which is below the spectral radius.

at_six_tenths =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rate = 0.6)
at_four_tenths =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rate = 0.4)

PCC.is_feasible(at_six_tenths), PCC.is_feasible(at_four_tenths)

# ## The best rate
#
# Without a `rate`, [`certify`](@ref) bisects on the rate, one feasibility
# problem per step, and returns the certificate at the tightest rate this
# template can certify on this graph.

result =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rtol = 1e-2)

result.rate

# ## What a certificate is
#
# [`functions`](@ref) returns fitted sets, one per node. Use
# [`node_value`](@ref) to evaluate the corresponding node function.

V = PCC.functions(result)
length(V), PCC.node_value(problem, V[1], [1.0, 1.0])

# The node functions combine into the common function, whose form depends on
# the graph; here it is their minimum, because the graph is complete. A
# certificate is callable: `result(x)` evaluates the common function at `x`.

x = [1.0, 1.0]
result(x)

# !!! warning "A bound is an upper bound"
#     An infeasible result means no certificate was found in this template on
#     this graph, not that the system is unstable. See
#     [What works with what](@ref) for the templates available, and
#     [Choosing a template](@ref) and [Choosing a graph](@ref) to try others.
