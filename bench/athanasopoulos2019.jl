# Example 2 of Athanasopoulos & Jungers, "Polyhedral path-complete Lyapunov
# functions", CDC 2019: a two-mode system in three dimensions, the fixed-facet
# polyhedral template with the identity at every node, and the four partial
# lifts tried at every tight edge with the best candidate kept. The paper proves
# stability at the fifteenth step, with a final graph of 1533 edges.
#
# Run with an environment that has a solver:
#
#     julia --project=docs bench/athanasopoulos2019.jl [depth_max]
#
# Prints one line per step -- nodes, edges, the certified rate -- and the
# status. Numbers depend on tie-breaking and the LP solver, so a different
# step count is not a defect; the rate falling below one is the claim.

import PathCompleteCertificates as PCC
import Clarabel

const A1 = [0.095 -0.2375 0.2375; -1.9 0.0 0.0; 0.0 0.0 0.475]
const A2 = [0.4753 0.0 0.0; 0.0 0.0 0.4753; 0.0 -1.9012 0.0]

depth_max = isempty(ARGS) ? 15 : parse(Int, ARGS[1])

problem = PCC.StabilityProblem(PCC.switched_system([A1, A2]))
template = PCC.PolyhedralTemplate(1, 3)

elapsed = @elapsed trace = PCC.refine(
    template,
    problem;
    optimizer = Clarabel.Optimizer,
    strategy = PCC.LiftTightEdges(),
    select = :best,
    stop = c -> c.rate < 1,
    depth_max = depth_max,
    atol = 1e-4,
)

for (k, certificate) in enumerate(PCC.certificates(trace))
    g = PCC.graph(certificate)
    println(
        "step ",
        lpad(k, 2),
        "  nodes ",
        lpad(PCC.n_nodes(g), 3),
        "  edges ",
        lpad(PCC.n_edges(g), 5),
        "  rate ",
        round(certificate.rate; digits = 5),
    )
end

println("status ", PCC.status(trace), "  in ", round(elapsed; digits = 1), " s")
