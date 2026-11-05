# # Improve my bound
#
# In [Bound the joint spectral radius of my system](@ref), a De Bruijn graph
# with four nodes proved stability, and left a gap between its rate and the
# joint spectral radius. Here the package designs the graph: it proves
# stability with three nodes, and finds the exact joint spectral radius with
# ten. [Refining the graph](@ref) explains refinement, and this page runs it.

using PathCompleteCertificates
import Clarabel
import LinearAlgebra
using Plots
include(joinpath(pkgdir(PathCompleteCertificates), "docs", "graph_drawing.jl")) #hide

const TEMPLATE = QuadraticTemplate()
const OPTIMIZER = Clarabel.Optimizer
nothing #hide

# ## The system
#
# The rotation and the shear of [Bound the joint spectral radius of my system](@ref).

A = [0.75 * [0.0 1.0; -1.0 0.0], 0.75 * [1.0 1.0; 0.0 1.0]]
problem = StabilityProblem(switched_system(A))
nothing #hide

# ## One call
#
# [`refine`](@ref) starts from the common graph and adds nodes where the
# certificate is tight. By default it splits the node with the most tight
# outgoing edges ([`TightestNodeSplitting`](@ref)), and the keyword `strategy`
# chooses another (see [Refining the graph](@ref)). `depth_max` raises the
# number of graphs it may visit, 5 by default. For each graph it visits, its
# number of nodes, the certified rate, and the lower bound read from the tight
# edges:

trace = refine(TEMPLATE, problem; optimizer = OPTIMIZER, depth_max = 10)

progress = [
    (n_nodes(graph), certificate.rate, jsr_lower_bound(certificate)) for
    (graph, certificate) in zip(graphs(trace), certificates(trace))
]

# The rate goes below one at three nodes. The lower bound then rises to meet
# the rate, and the run stops at ten nodes with a proof that the rate is the
# joint spectral radius:

status(trace)

# The De Bruijn graphs, for comparison, go below one only at order 2, with four
# nodes:

hierarchy = [
    (2^k, certify(TEMPLATE, de_bruijn(k, 2), problem; optimizer = OPTIMIZER).rate) for
    k in 0:3
]

# ## The bounds, drawn
#
# On the left, the two bounds of each step against the number of nodes, and
# the rates of the De Bruijn graphs, whose nodes double with the order. The
# first lower bounds, ``0.75``, fall below the chart. On the right, the last
# graph, its tight edges in bold: every node keeps at most one tight outgoing
# edge, which proves the rate exact, and the tight edges form one cycle, which
# reads the slowest sequence ``2, 2, 2, 2, 1``.

left = plot(;
    xlabel = "number of nodes",
    ylabel = "bound on the joint spectral radius",
    legend = :topright,
    ylims = (0.94, 1.07),
    title = "refine against De Bruijn",
)
plot!(
    left,
    first.(progress),
    getindex.(progress, 2);
    marker = :circle,
    lw = 2,
    color = :black,
    label = "refine, upper bound",
)
plot!(
    left,
    first.(progress),
    last.(progress);
    marker = :circle,
    lw = 2,
    ls = :dash,
    color = :black,
    label = "refine, lower bound",
)
plot!(
    left,
    first.(hierarchy),
    last.(hierarchy);
    marker = :square,
    lw = 2,
    color = :steelblue,
    label = "De Bruijn, upper bound",
)
hline!(left, [1.0]; color = :red, ls = :dot, label = "stability threshold")

final = last(certificates(trace))
right = draw_tight_edges(final) #hide

plot(left, right; layout = (1, 2), size = (900, 500), margin = 5Plots.mm)

# ## What it proves
#
# [`is_jsr_exact`](@ref) confirms the proof, and the rate matches the slowest
# product of [Bound the joint spectral radius of my system](@ref), the
# sequence ``2, 2, 2, 2, 1``:

slowest = maximum(abs, LinearAlgebra.eigvals(A[1] * A[2]^4))^(1 / 5)
is_jsr_exact(final), final.rate, slowest
