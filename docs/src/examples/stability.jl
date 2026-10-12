# # Stability: a first certificate
#
# The smallest complete thing the package does: take a switched linear system,
# take a path-complete graph, and get back an upper bound on the joint spectral
# radius together with the node functions that prove it.

import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

# One mode, a diagonal contraction. Its joint spectral radius is its spectral
# radius, `0.5`, which makes the answer checkable by hand.

A = [[0.5 0.0; 0.0 0.25]]

# The graph is the De Bruijn graph of order 1 over one mode: a single node with
# a self-loop, the smallest path-complete graph there is.

graph = PCC.de_bruijn(1, 1)
problem = PCC.StabilityProblem(PCC.switched_system(A))

# ## One solve at a given rate
#
# [`certify`](@ref) asks whether the system contracts at a given rate on this
# graph, in this template. The result is a certificate either way, and
# [`is_feasible`](@ref) says which.

at_six_tenths =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rate = 0.6)
at_four_tenths =
    PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = OPTIMIZER, rate = 0.4)

PCC.is_feasible(at_six_tenths), PCC.is_feasible(at_four_tenths)

# ## The best rate
#
# [`jsr_bound`](@ref) bisects on the rate, one feasibility problem per step,
# and returns the certificate at the tightest rate this template can certify
# on this graph.

result = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-2,
)

result.rate

# ## What a certificate is
#
# More than the number. [`functions`](@ref) are the fitted node functions, one
# per node, each callable.

V = PCC.functions(result)
length(V), V[1]([1.0, 1.0])

# The single function that certifies the system is the common function they
# combine into, which depends on the graph: a minimum here, because the graph
# is complete. The certificate is callable, and `certificate(x)` evaluates it.

x = [1.0, 1.0]
result(x)

# !!! warning "A bound is an upper bound"
#     An infeasible result means no certificate was found in this template on
#     this graph, not that the system is unstable. See
#     [What works with what](@ref) for the templates available, and
#     [Templates and graphs: the two axes](@ref) for how much the choice
#     matters.
