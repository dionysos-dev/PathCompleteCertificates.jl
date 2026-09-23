# # Stability: a first certificate
#
# The smallest complete thing the package does: take a switched linear system,
# take a path-complete graph, and get back an upper bound on the joint spectral
# radius together with the node functions that prove it.

import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

# One mode, a diagonal contraction. Its joint spectral radius is just its
# spectral radius, `0.5`, which makes the answer checkable by hand.

A = [[0.5 0.0; 0.0 0.25]]

# The graph is a De Bruijn graph of order 1 over 1 mode — a single node with a
# self-loop, the smallest path-complete graph there is. `:complete` orientation
# means every node has an outgoing edge for every mode, which is what lets
# [`common`](@ref) aggregate with a minimum.

graph = PCC.de_bruijn(1, 1; orientation = :complete)
problem = PCC.StabilityProblem(PCC.switched_system(A))

# `jsr_bound` bisects on the rate, solving one feasibility problem per step,
# and returns the tightest rate this template can certify on this graph.

result = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    graph,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-2,
)

result.rate

# The certificate is more than the number. `functions` are the fitted node
# functions, one per node, and each is callable.

V = PCC.functions(result)
length(V), V[1]([1.0, 1.0])

# The single function that certifies the system is their aggregate. Which
# aggregate is correct depends on the graph, and `common` dispatches on that —
# a minimum here, because the graph is complete.

x = [1.0, 1.0]
PCC.common(PCC.QuadraticTemplate(), graph, problem, PCC.functions(result), x)

# The certificate is itself callable, and `certificate(x)` *is* the common
# function — the same value, without having to reassemble the arguments.

result(x)

# !!! warning "A bound is an upper bound"
#     `is_stable` returning `false` means no certificate was found in this
#     template on this graph — not that the system is unstable. See
#     [What works with what](@ref) for which templates are available, and
#     [`two_axes.jl`](@ref "The two axes, drawn") for how much the choice
#     matters.
