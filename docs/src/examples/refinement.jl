# # Refinement: letting the graph design itself
#
# Every other example hands `certify` a graph you chose. This one does not:
# [`refine`](@ref) starts from the memoryless graph and grows it, reading off
# which edge inequalities the solver is held at and splitting the node that is
# being asked to do too much ([ninite2026lifting](@cite)).
#
# The result beats a De Bruijn graph of the same size, which is the point — the
# graph axis of [The two axes, drawn](@ref) stops being something you guess at.

import PathCompleteCertificates as PCC
import Clarabel
using HybridSystems
using Plots

const OPTIMIZER = Clarabel.Optimizer
const TEMPLATE = PCC.QuadraticTemplate()

# A rotation and a shear. No single quadratic attains the joint spectral radius
# of this pair, so the memoryless bound is loose and there is something to win.

A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

# The seed: one node, one self-loop per mode.

seed = GraphAutomaton(1)
add_transition!(seed, 1, 1, 1)
add_transition!(seed, 1, 1, 2)

# ## Running the loop

trace = PCC.refine(TEMPLATE, seed, problem; optimizer = OPTIMIZER, depth_max = 4)

# No seed, and none needed: ties go to the **cheapest** split — the one adding
# fewest nodes — so this run is identical on every machine and Julia version.

sizes = PCC.n_nodes.(PCC.graphs(trace))
bounds = PCC.rates(trace)

collect(zip(sizes, round.(bounds; digits = 5)))

# Why it stopped is part of the answer, so it is a [`RefinementStatus`](@ref) and
# not a flag. Here the budget ran out with the bound still falling.

PCC.status(trace)

# ## How far from the truth?
#
# The certified rate is an *upper* bound on the joint spectral radius. Every cycle
# of the graph gives a **lower** one — a periodic product cannot contract faster
# than the worst switching sequence — so the two bracket the answer
# ([`jsr_lower_bound`](@ref)).

collect(zip(sizes, round.(PCC.lower_bounds(trace); digits = 5), round.(bounds; digits = 5)))

# The bracket is what lets [`refine`](@ref) stop with [`OPTIMAL`](@ref) rather
# than merely out of ideas, and it is sound whatever tolerance decided tightness:
# a cycle of the tight subgraph is still a cycle of the graph.
#
# It also covers the case the structural test cannot. Two opposite rotations of
# the same magnitude have a joint spectral radius their memoryless quadratic
# certificate already attains — but *every* edge is then tight, so
# [`is_jsr_exact`](@ref), which needs at most one tight edge per node, never
# fires. The bracket closes at the first step instead.

turn(angle) = 0.9 .* [cos(angle) -sin(angle); sin(angle) cos(angle)]
rotations = PCC.StabilityProblem(PCC.switched_system([turn(pi / 3), turn(-pi / 3)]))

exact = PCC.refine(TEMPLATE, PCC.de_bruijn(1, 2), rotations; optimizer = OPTIMIZER)

PCC.status(exact), round(PCC.rates(exact)[end]; digits = 6)

# !!! note "Why the lift splits per edge"
#     [`ForwardEdgeLift`](@ref) makes one copy per outgoing **edge**. The paper
#     splits per distinct **successor** — and the seed's only successor is itself,
#     so that grain could not take a single step here.
#
#     It is also what makes the split rule and Theorem 4 the same test, since both
#     then count outgoing edges.

# ## Against De Bruijn
#
# The honest comparison is at equal size: a graph with `n` nodes carries `n`
# quadratic functions either way, so node count is the budget.

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
    title = "the same budget, spent better",
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

# At two nodes the bounds coincide: the edge-grained lift of the memoryless graph
# is the *transpose* of `de_bruijn(1, 2)` — co-complete where that one is
# complete — and on this system the two certify the same rate. At four nodes they
# part: refinement reaches `0.9043` where `de_bruijn(2, 2)` stops at `0.9055`.
# De Bruijn spends its nodes on remembering the last two modes whether or not
# that is where the certificate was tight; refinement spends them where the
# solver said it hurt.

# ## What the certificate looks like
#
# `RefinementTrace` carries the certificates themselves, not only the bounds, so
# the shapes come for free. Each is positively homogeneous of degree
# [`rate_exponent`](@ref), so the radius of ``\{V \le 1\}`` in direction ``u``
# is ``V(u)^{-1/d}`` — the trick [The sum-of-squares hierarchy](@ref) uses.

function sublevel_boundary(certificate; samples = 721)
    degree = PCC.rate_exponent(PCC.template(certificate))
    angles = range(0, 2pi; length = samples)
    radii = [certificate([cos(a), sin(a)])^(-1 / degree) for a in angles]
    radii ./= maximum(radii)

    return radii .* cos.(angles), radii .* sin.(angles)
end

shapes = plot(;
    title = "one ellipse per node, intersected\n(shape only — scale is arbitrary)",
    aspect_ratio = :equal,
    legend = :outerbottom,
    framestyle = :origin,
)

for (n, certificate) in zip(sizes, PCC.certificates(trace))
    xs, ys = sublevel_boundary(certificate)
    plot!(shapes, xs, ys; lw = 2, label = "$n node(s)")
end

shapes

# Every graph the loop visits here is **co-complete**, so [`common`](@ref)
# aggregates the node functions with a maximum and the unit ball is their
# *intersection* — convex, and gaining a facet per node. That is the opposite of
# the primal De Bruijn case, where the aggregation is a minimum and the ball is a
# non-convex union; the lift builds the dual family.

PCC.is_co_complete.(PCC.graphs(trace))

# ## Soundness
#
# A lift that lost path-completeness would produce certificates that certify
# nothing, silently. It does not, and this is checkable rather than asserted:

all(graph -> PCC.is_path_complete(graph, 1:length(A)), PCC.graphs(trace))

# !!! note "Path-completeness *is* the whole soundness argument"
#     A lift is defined as a map on graphs preserving it, so the check above is
#     the guarantee. A template's closure properties decide something else —
#     whether the lift is *valid*, meaning the lifted graph is no **worse** — and
#     the forward lifts need none, since each copy inherits the split node's
#     function. [`refine`](@ref) takes a [`QuadraticTemplate`](@ref) because that
#     is what is tested.
