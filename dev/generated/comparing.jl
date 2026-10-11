import PathCompleteCertificates as PCC
import Clarabel
using HybridSystems
using Plots

const OPTIMIZER = Clarabel.Optimizer

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

[
    (
        name,
        PCC.is_path_complete(g, 1:2),
        PCC.is_complete(g, 1:2),
        PCC.is_co_complete(g, 1:2),
    ) for (name, g) in zip(NAMES, GRAPHS)
]

A = [[1.5519 0.44737; 7.6412 7.4716], [0.47501 9.1755; 1.8955 0.18502]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)

QUADRATIC = PCC.QuadraticTemplate()
COPOSITIVE = PCC.LinearCopositiveTemplate()
DUAL_COPOSITIVE = PCC.DualCopositiveTemplate()
TEMPLATES = (QUADRATIC, COPOSITIVE, DUAL_COPOSITIVE)

c12 = PCC.compare(G1, G2; templates = TEMPLATES, system, optimizer = OPTIMIZER)
PCC.lifts(c12)

first.(PCC.simulations(c12))

PCC.templates(c12)

C = Dict(PCC.simulations(c12))[PCC.SumLift()]

combination(row) = join(
    [(c == 1 ? "" : "$c·") * "V_" * node_name(g) for (g, c) in enumerate(row) if c > 0],
    " + ",
)

["W_" * node_name(h) * " = " * combination(C[h, :]) for h in 1:PCC.n_nodes(G2)]

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

c40 = PCC.compare(G4, G0; templates = TEMPLATES, system, optimizer = OPTIMIZER)
first.(PCC.simulations(c40)), PCC.templates(c40)

c30 = PCC.compare(G3, G0; templates = TEMPLATES, system, optimizer = OPTIMIZER)
Dict(PCC.simulations(c30))[PCC.SumLift()]

c04 = PCC.compare(G0, G4; templates = TEMPLATES, system)
PCC.lifts(c04), PCC.templates(c04)

RATES = [
    (name, [bound(template, g).rate for g in GRAPHS]) for (name, template) in (
        ("quadratic", QUADRATIC),
        ("copositive", COPOSITIVE),
        ("dual copositive", DUAL_COPOSITIVE),
    )
]

rows = [hcat(name, round.(rates; digits = 4)') for (name, rates) in RATES]

vcat(reshape(["template"; NAMES], 1, :), rows...)

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

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
