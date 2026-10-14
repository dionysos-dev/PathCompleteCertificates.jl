# # Refinement: splitting nodes at tight edges
#
# [`refine`](@ref) starts from a small graph and enlarges it: after each solve
# it reads which edge inequalities are tight and splits the node with the most
# tight outgoing edges, one copy per successor ([ninite2026lifting](@cite)).
# On the system below, at four nodes, it certifies a lower rate than the De
# Bruijn graph of the same size.

import PathCompleteCertificates as PCC
import SetProg
import Clarabel
using Plots

const OPTIMIZER = Clarabel.Optimizer
const TEMPLATE = SetProg.Ellipsoid(; symmetric = true)

# A rotation and a shear. No single quadratic function attains the joint
# spectral radius of this pair, so the bound on the one-node graph is not
# exact.

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

# ## Running the loop
#
# Each step solves [`jsr_bound`](@ref), reads the tight edges, and applies a
# lift. The default algorithm, [`TightNodeSplitting`](@ref), splits the node
# with the most tight outgoing edges, and among those the one with the fewest
# outgoing edges, so the run is deterministic. It starts, as in
# [ninite2026lifting](@cite), from the dual De Bruijn graph of order 1: the
# one-node graph has a single successor, itself, so splitting it changes
# nothing.

trace = PCC.refine(TEMPLATE, problem; optimizer = OPTIMIZER, depth_max = 4)

sizes = PCC.n_nodes.(PCC.graphs(trace))
bounds = PCC.rates(trace)

collect(zip(sizes, round.(bounds; digits = 5)))

# The reason the loop stopped is a [`RefinementStatus`](@ref). Here the depth
# budget ran out while the bound was still decreasing.

PCC.status(trace)

# ## Lower bounds
#
# The certified rate is an upper bound on the joint spectral radius. Every
# cycle of the tight subgraph gives a lower bound, since the joint spectral
# radius is at least the spectral radius of a product of length ``k`` to the
# power ``1/k`` ([`jsr_lower_bound`](@ref)).

lower = PCC.jsr_lower_bound.(PCC.certificates(trace))

collect(zip(sizes, round.(lower; digits = 5), round.(bounds; digits = 5)))

# When the two bounds meet, the loop stops with [`OPTIMAL`](@ref). This covers
# a case the structural test of [`is_jsr_exact`](@ref) does not: two opposite
# rotations of the same magnitude
# have a joint spectral radius their one-node quadratic certificate already
# attains, but every edge is then tight, so no node has a single tight
# outgoing edge. The two bounds meet at the first step.

turn(angle) = 0.9 .* [cos(angle) -sin(angle); sin(angle) cos(angle)]
rotations = PCC.StabilityProblem(PCC.switched_system([turn(pi / 3), turn(-pi / 3)]))

exact = PCC.refine(TEMPLATE, PCC.de_bruijn(1, 2), rotations; optimizer = OPTIMIZER)

PCC.status(exact), round(PCC.rates(exact)[end]; digits = 6)

# ## Against De Bruijn
#
# The comparison is at equal numbers of nodes, since a graph with `n` nodes
# carries `n` quadratic functions in either construction.

de_bruijn = map([1, 2]) do order
    graph = PCC.de_bruijn(order, 2)
    certificate = PCC.jsr_bound(TEMPLATE, graph, problem; optimizer = OPTIMIZER)

    return PCC.n_nodes(graph), certificate.rate
end

plot(
    sizes,
    bounds;
    marker = :circle,
    markersize = 5,
    lw = 2,
    label = "refine",
    xlabel = "number of nodes",
    ylabel = "certified rate",
    xticks = sizes,
    legend = :topright,
    title = "refine against De Bruijn",
)
plot!(
    first.(de_bruijn),
    last.(de_bruijn);
    marker = :square,
    markersize = 6,
    lw = 2,
    ls = :dash,
    label = "de_bruijn",
)

# At two nodes the bounds coincide: the run starts from the dual of
# `de_bruijn(1, 2)`, and on this system the two certify the same rate.
# At four nodes the refined graph certifies a lower rate. The nodes of
# `de_bruijn(2, 2)` are the pairs of last modes, independently of which edges
# were tight; refinement adds a node only by splitting one with tight outgoing
# edges.

# ## Soundness
#
# A lift maps path-complete graphs to path-complete graphs, so every
# certificate in the trace is sound; the line below checks every graph. The
# bound never increases, for any template, since each copy of a split node can
# take the function of the node it replaces.

all(graph -> PCC.is_path_complete(graph, 1:length(A)), PCC.graphs(trace))
