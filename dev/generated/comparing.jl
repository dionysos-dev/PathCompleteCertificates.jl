import PathCompleteCertificates as PCC
import Clarabel
using Plots
include(joinpath(pkgdir(PCC), "docs", "graph_drawing.jl")) #hide

const OPTIMIZER = Clarabel.Optimizer
nothing #hide

function build(n_nodes, edges)
    graph = PCC.empty_graph(n_nodes)
    for (a, b, mode) in edges
        PCC.add_edge!(graph, a, b, mode)
    end
    return graph
end

G0 = build(1, [(1, 1, 1), (1, 1, 2)])
G1 = build(
    5,
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
)
G2 = build(
    4,
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
)
G3 = build(
    5,
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
)
G4 = build(
    5,
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
)

GRAPHS = [G0, G1, G2, G3, G4]
NAMES = ["G0", "G1", "G2", "G3", "G4"]
node_name(k) = string('a' + k - 1)

draw_graphs(GRAPHS, NAMES; node_label = node_name) #hide

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
TEMPLATES = [
    "quadratic" => QUADRATIC,
    "copositive" => PCC.LinearCopositiveTemplate(),
    "dual copositive" => PCC.DualCopositiveTemplate(),
]
nothing #hide

compared(G, H) =
    PCC.compare(G, H; templates = last.(TEMPLATES), system, optimizer = OPTIMIZER)
lift_name(lift) =
    lift isa PCC.MinLift ? "min" :
    lift isa PCC.MaxLift ? "max" :
    lift isa PCC.SumLift ? "sum" : string(nameof(typeof(lift)))
outcome(c) = (
    simulating = lift_name.(first.(PCC.simulations(c))),
    proved_for = [
        name for (name, template) in TEMPLATES if any(t -> t === template, PCC.templates(c))
    ],
)

c12 = compared(G1, G2)
outcome(c12)

C = Dict(PCC.simulations(c12))[PCC.SumLift()]
combination(row) = join(
    [(c == 1 ? "" : "$c·") * "V_" * node_name(g) for (g, c) in enumerate(row) if c > 0],
    " + ",
)
["W_" * node_name(h) * " = " * combination(C[h, :]) for h in 1:PCC.n_nodes(G2)]

bound(template, graph) =
    PCC.certify(template, graph, problem; optimizer = OPTIMIZER, initial_upper = 100.0)

on_G1 = bound(QUADRATIC, G1)
V = PCC.functions(on_G1)
W = [
    PCC.QuadraticFunction(sum(C[h, g] * V[g].Q for g in eachindex(V))) for
    h in 1:PCC.n_nodes(G2)
]
scale = on_G1.rate^PCC.homogeneity_degree(QUADRATIC)
all(PCC.edges(G2)) do edge
    return PCC.decrease_slack(
        QUADRATIC,
        W[PCC.source(edge)],
        W[PCC.dest(edge)],
        A[PCC.label(G2, edge)];
        scale,
    ) >= -1e-6
end

c40 = compared(G4, G0)
outcome(c40)

c30 = compared(G3, G0)
Dict(PCC.simulations(c30))[PCC.SumLift()]

rates = Dict(
    name => [bound(template, g).rate for g in GRAPHS] for (name, template) in TEMPLATES
)

figure = plot(;
    xticks = (1:5, NAMES),
    ylabel = "certified rate",
    legend = :outerright,
    size = (800, 420),
    title = "five graphs, three templates",
)
for (name, _) in TEMPLATES
    plot!(figure, 1:5, rates[name]; marker = :circle, markersize = 6, lw = 2, label = name)
end
figure

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
