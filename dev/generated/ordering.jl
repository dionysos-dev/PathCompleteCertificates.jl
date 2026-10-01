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

all(g -> PCC.is_path_complete(g, 1:2), GRAPHS)

[
    (name, PCC.is_complete(g, 1:2), PCC.is_co_complete(g, 1:2)) for
    (name, g) in zip(NAMES, GRAPHS)
]

PCC.simulation(G1, G2) === nothing

C = PCC.conic_witness(G1, G2; optimizer = OPTIMIZER)

combination(row) = join(
    [(c == 1 ? "" : "$c·") * "V_" * node_name(g) for (g, c) in enumerate(row) if c > 0],
    " + ",
)

["W_" * node_name(h) * " = " * combination(C[h, :]) for h in 1:PCC.n_nodes(G2)]

A = [[1.5519 0.44737; 7.6412 7.4716], [0.47501 9.1755; 1.8955 0.18502]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)
QUADRATIC = PCC.QuadraticTemplate()

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
scale = on_G1.rate^PCC.rate_exponent(QUADRATIC)

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

witness = PCC.order_witness(G1, G2; template = QUADRATIC, system, optimizer = OPTIMIZER)
witness.kind

PCC.is_no_worse(G2, G1; template = QUADRATIC, system, optimizer = OPTIMIZER)

C3 = PCC.conic_witness(G3, G0; optimizer = OPTIMIZER)

PCC.conic_witness(G4, G0; optimizer = OPTIMIZER) === nothing

PCC.closed_subgraph(G4, 1:2; direction = :in)

witness = PCC.order_witness(G4, G0; template = PCC.DualCopositiveTemplate(), system)
witness.kind, witness.data

(
    PCC.n_nodes(PCC.simplify(G4; template = PCC.DualCopositiveTemplate(), system)),
    PCC.n_nodes(PCC.simplify(G4; template = QUADRATIC, system)),
)

TEMPLATES = [
    ("quadratic", QUADRATIC),
    ("copositive", PCC.LinearCopositiveTemplate()),
    ("dual copositive", PCC.DualCopositiveTemplate()),
]

RATES =
    [(name, [bound(template, g).rate for g in GRAPHS]) for (name, template) in TEMPLATES]

rows = [hcat(name, round.(rates; digits = 4)') for (name, rates) in RATES]

vcat(reshape(["template"; NAMES], 1, :), rows...)

PCC.is_valid(PCC.MinLift(), PCC.LinearCopositiveTemplate(), system)

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

sum_lift = PCC.SumLift(2)(G1)
R_sum = PCC.simulation(PCC.graph(sum_lift), G2)

[
    node_name(h) *
    "₂ ↦ {" *
    join(node_name.(PCC.origins(sum_lift)[R_sum[h]]) .* "₁", ", ") *
    "}" for h in 1:PCC.n_nodes(G2)
]

min_lift = PCC.MinLift()(G4)
R = PCC.simulation(PCC.graph(min_lift), G0)

"a₀ ↦ {" * join(node_name.(PCC.origins(min_lift)[R[1]]) .* "₄", ", ") * "}"

PCC.n_nodes(PCC.graph(sum_lift)), PCC.n_nodes(PCC.graph(min_lift))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
