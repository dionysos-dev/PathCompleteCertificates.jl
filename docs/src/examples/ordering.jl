# # Comparing graphs: which one is better?
#
# Two path-complete graphs and one template: is a certificate on the first
# guaranteed to give one on the second, whatever the system? That ordering is
# the question the package is built around — the graph is the object of study,
# not a device for a bound — and its answer depends on what the template is
# closed under. This example decides it on the five graphs of
# [debauche2023ordering](@cite) and its repeatability package with one call,
# reads the simulation behind every verdict, and confirms each with certified
# rates.

import PathCompleteCertificates as PCC
import Clarabel
using HybridSystems
using Plots

const OPTIMIZER = Clarabel.Optimizer

# ## Five graphs on two modes
#
# A certificate graph is a `GraphAutomaton` with a mode on every edge. Its nodes
# are numbered; the paper names them `a` to `e`, and so does everything printed
# below.

function graph(edges, n_nodes)
    g = GraphAutomaton(n_nodes)
    for (s, d, mode) in edges
        add_transition!(g, s, d, mode)
    end
    return g
end

node_name(k) = string('a' + k - 1)

G0 = graph([(1, 1, 1), (1, 1, 2)], 1)
G1 = graph(
    [
        (1, 2, 1),
        (2, 1, 1),
        (1, 3, 1),
        (3, 1, 2),
        (1, 4, 2),
        (4, 1, 1),
        (1, 5, 2),
        (5, 1, 2),
    ],
    5,
)
G2 = graph(
    [
        (1, 3, 2),
        (1, 4, 2),
        (2, 1, 1),
        (2, 2, 1),
        (3, 3, 2),
        (3, 4, 2),
        (4, 2, 1),
        (4, 1, 1),
    ],
    4,
)
G3 = graph(
    [
        (1, 2, 1),
        (1, 5, 2),
        (1, 4, 1),
        (2, 3, 1),
        (2, 4, 2),
        (3, 4, 1),
        (3, 4, 2),
        (4, 3, 2),
        (4, 2, 2),
        (4, 5, 1),
        (5, 1, 1),
        (5, 1, 2),
    ],
    5,
)
G4 = graph(
    [
        (1, 2, 1),
        (2, 4, 1),
        (3, 2, 1),
        (4, 3, 1),
        (4, 5, 1),
        (5, 1, 1),
        (1, 4, 2),
        (1, 3, 2),
        (2, 1, 2),
        (3, 2, 2),
        (4, 5, 2),
        (5, 1, 2),
    ],
    5,
)

GRAPHS = [G0, G1, G2, G3, G4]
NAMES = ["G0", "G1", "G2", "G3", "G4"]

# `G0` is the one-node graph: a common Lyapunov function. All five read every
# word over the two modes, which is the soundness condition and all that a
# certificate on any of them needs.

all(g -> PCC.is_path_complete(g, 1:2), GRAPHS)

# They differ in how they read them. A graph is *complete* when every node has
# an outgoing edge for every mode, *co-complete* when every node has an incoming
# one. `G0`, `G3` and `G4` are both; `G1` and `G2` are neither.

[
    (name, PCC.is_complete(g, 1:2), PCC.is_co_complete(g, 1:2)) for
    (name, g) in zip(NAMES, GRAPHS)
]

# ## One call
#
# [`compare`](@ref)`(G, H)` decides whether `H` is no worse than `G`, written
# ``G \le_V H``: every system certified on `G` in a template ``V`` is certified
# on `H` in the same template. It tries every lift of the literature, cheapest
# first, and records which ones found a simulation of `H` by the lifted `G`.
# Given templates and the system they will be read on, it also says for which
# of them the verdict holds.

A = [[1.5519 0.44737; 7.6412 7.4716], [0.47501 9.1755; 1.8955 0.18502]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)

QUADRATIC = PCC.QuadraticTemplate()
COPOSITIVE = PCC.LinearCopositiveTemplate()
DUAL_COPOSITIVE = PCC.DualCopositiveTemplate()
TEMPLATES = (QUADRATIC, COPOSITIVE, DUAL_COPOSITIVE)

c12 = PCC.compare(G1, G2; templates = TEMPLATES, system, optimizer = OPTIMIZER)
PCC.lifts(c12)

# Six lifts were tried. The first, the identity lift, is the order that holds
# for every template ([philippe2019complete](@cite)): a map from the nodes of
# `G2` to those of `G1` carrying every edge onto an edge with the same mode.
# None exists, since `G2` has a self-loop and `G1` has none — the paper's
# Example 1. Three lifts did find one:

first.(PCC.simulations(c12))

# The sum lift's is the verdict the paper is about, and it carries the other
# two with it: whenever a sum lift of `G1` simulates `G2`, so do its min and
# max lifts ([debauche2024thesis](@cite), Cor. 7.80). Together they settle the
# three templates — the quadratic and copositive norms add, the dual copositive
# norms are closed under maximum.

PCC.templates(c12)

# ## Reading a simulation: the matrix
#
# For a template closed under addition a *sum* of node functions is a candidate
# too, and the paper builds a certificate on `G2` from one on `G1` by hand:
# ``W_a = V_a + V_c``, ``W_b = V_a + V_b``, and so on. The sum lift's simulation is
# that construction as a nonnegative integer matrix ``C`` with ``W = C\,V``,
# found by a linear program that is **complete** for the order: feasible
# exactly when some sum lift of `G1` simulates `G2`
# ([debauche2023ordering](@cite), Thm. 2). Rows are the nodes of `G2`, columns
# those of `G1`.

C = Dict(PCC.simulations(c12))[PCC.SumLift()]

# Read off, it is the paper's construction; the program has several solutions
# and this is one of them.

combination(row) = join(
    [(c == 1 ? "" : "$c·") * "V_" * node_name(g) for (g, c) in enumerate(row) if c > 0],
    " + ",
)

["W_" * node_name(h) * " = " * combination(C[h, :]) for h in 1:PCC.n_nodes(G2)]

# A matrix is what you check by hand. Take a quadratic certificate on `G1` for
# the paper's system, combine its node matrices with ``C``, and every edge
# inequality of `G2` holds at the same rate: the slack of each is nonnegative.

bound(template, g) = PCC.jsr_bound(
    template,
    g,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-6,
    initial_upper = 100.0,
)

on_G1 = bound(QUADRATIC, G1)
V = PCC.functions(on_G1)
W = [
    PCC.QuadraticFunction(sum(C[h, g] * Matrix(V[g]) for g in eachindex(V))) for
    h in 1:PCC.n_nodes(G2)
]
scale = on_G1.rate^PCC.homogeneity_degree(QUADRATIC)

slacks = [
    PCC.domination_slack(
        QUADRATIC,
        W[PCC.source(e)],
        W[PCC.dest(e)],
        A[PCC.label(G2, e)];
        scale,
    ) for e in PCC.edges(G2)
]

all(>=(-1e-6), slacks)

# ## The same two graphs, ordered differently by the template
#
# `G4` against the one-node graph. It is complete and co-complete, so both
# subset lifts simulate `G0` by the full set of its nodes: the minimum of its
# node functions is a common function, and so is the maximum. No sum lift
# does, and the linear program says so.

c40 = PCC.compare(G4, G0; templates = TEMPLATES, system, optimizer = OPTIMIZER)
first.(PCC.simulations(c40))

#-

Dict(PCC.simulations(c40))[PCC.MaxLift()]

# So `G4` buys nothing over a common function for the copositive templates —
# the primal norms by the min lift, valid for them on positive systems without
# closure ([debauche2024thesis](@cite), Thm. 7.43), the dual norms by the max
# lift — and is strictly better for the quadratic one, since the program is
# complete and found nothing.

PCC.templates(c40)

# `G3`, also five nodes and twelve edges, is different: the program has a
# solution, a single row, so for every addition-closed template it certifies
# nothing the one-node graph would not. Whenever ``V`` certifies `G3`,
# ``2V_a + V_b + V_c + 2V_d + 2V_e`` is a common Lyapunov function. The paper
# proves this through the 8-sum lift of `G3`, whose nodes are the 495 multisets
# of eight of its nodes; the program never builds it.

c30 = PCC.compare(G3, G0; templates = TEMPLATES, system, optimizer = OPTIMIZER)
Dict(PCC.simulations(c30))[PCC.SumLift()]

# The other way round needs no lift at all: the one-node graph simulates every
# graph, so the identity lift answers and nothing else is tried.

c04 = PCC.compare(G0, G4; templates = TEMPLATES, system)
PCC.lifts(c04), PCC.templates(c04)

# ## The rates agree
#
# Every verdict above holds for every system. On the paper's system — a
# positive one, so the copositive templates apply too — the certified rates say
# the same thing. The quadratic row falls from `G1` to `G2`, is equal on `G3`
# and `G0`, and is strictly lower on `G4` than on `G0`. The dual copositive row
# is equal on `G0`, `G3` and `G4`, which is the collapse.

RATES = [
    (name, [bound(template, g).rate for g in GRAPHS]) for (name, template) in (
        ("quadratic", QUADRATIC),
        ("copositive", COPOSITIVE),
        ("dual copositive", DUAL_COPOSITIVE),
    )
]

rows = [hcat(name, round.(rates; digits = 4)') for (name, rates) in RATES]

vcat(reshape(["template"; NAMES], 1, :), rows...)

# Drawn, the dependence on the template is one picture: `G4` sits below `G0`
# for the quadratic template and on it for the two copositive ones, while `G2`
# is the best of the five for all three.

figure = plot(;
    xticks = (1:5, NAMES),
    ylabel = "certified rate",
    legend = :bottomleft,
    title = "five graphs, three templates",
)
for (name, rates) in RATES
    plot!(figure, 1:5, rates; marker = :circle, markersize = 6, lw = 2, label = name)
end
figure

# ## The lifts, as exhibits
#
# The theory speaks of lifted graphs: the 2-sum lift of `G1`, whose nodes are
# the multisets of two of its nodes, simulates `G2`; the min lift of `G4`,
# whose nodes are the subsets, simulates `G0`. Both can be built with
# [`lift`](@ref), and [`simulation`](@ref) on a lift of fixed size does build
# it — this is what the repeatability package prints. Nothing above needed
# them: the relation and the linear program decide in polynomial time what the
# lifts exhibit in exponential size.

R_sum = PCC.simulation(PCC.SumLift(2), G1, G2)

[
    node_name(h) * "₂ ↦ {" * join(node_name.(R_sum[h]) .* "₁", ", ") * "}" for
    h in 1:PCC.n_nodes(G2)
]

#-

R_min = PCC.simulation(PCC.MinLift(), G4, G0)

"a₀ ↦ {" * join(node_name.(R_min[1]) .* "₄", ", ") * "}"

# Fifteen and thirty-one nodes, for questions answered on five.

PCC.n_nodes(PCC.graph(PCC.lift(PCC.SumLift(2), G1))),
PCC.n_nodes(PCC.graph(PCC.lift(PCC.MinLift(), G4)))

# !!! note "Where this sits"
#     [`compare`](@ref) answers *is this graph no worse than that one*, for
#     which templates, whatever the system. [`refine`](@ref) is the other
#     direction: start from a graph and build a better one where the certificate
#     is tight. [Graph comparison via lifts](@ref) explains the lifts and what each one
#     decides; [Graph improvement via refinements](@ref) the steps that improve.
