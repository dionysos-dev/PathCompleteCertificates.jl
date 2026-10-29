# Table "Upper bound on the JSR for several templates and graphs" of the HSCC'27
# tool paper: the pair of Section 5.2, five templates on the common graph and on
# the De Bruijn graphs of order 1 and 3.
#
# Run from the repository root:
#
#     julia --project=numerical_experiments -e 'using Pkg; Pkg.instantiate()'
#     julia --project=numerical_experiments numerical_experiments/templates_jsr.jl
#
# Prints the table, with the time of each solve, and writes it to
# numerical_experiments/results/templates_jsr.csv. The lower bound rho(A_1) is
# the JSR on this pair; a bound below it signals a solver tolerance too loose.

import PathCompleteCertificates as PCC
import Clarabel, JuMP
using SumOfSquares, DynamicPolynomials
using LinearAlgebra
using Printf

const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "verbose" => false,
    # with the default tolerances, the sum-of-squares bounds fall below rho(A_1)
    "tol_gap_abs" => 1e-10,
    "tol_gap_rel" => 1e-10,
    "tol_feas" => 1e-10,
)
const RTOL = 1e-6

A = [[1.631 0.793; 0.112 1.554], [0.287 0.366; 1.157 0.090]]
problem = PCC.StabilityProblem(PCC.switched_system(A))
const RHO = maximum(abs, eigvals(A[1]))

@polyvar x[1:2]

const GRAPHS = [
    ("Common", PCC.common_graph(problem.system)),
    ("De Bruijn 1", PCC.de_bruijn(1, 2)),
    ("De Bruijn 3", PCC.de_bruijn(3, 2)),
]

# The polyhedral templates carry data per node, hence are built for each graph.
const TEMPLATES = [
    ("Quadratic", n -> PCC.QuadraticTemplate()),
    ("Sum of squares, r = 2", n -> PCC.SumOfSquaresTemplate(2, x)),
    ("Sum of squares, r = 3", n -> PCC.SumOfSquaresTemplate(3, x)),
    ("Parallel faces, F_s = I", n -> PCC.ParallelFacesPolyhedralTemplate(n, 2)),
    (
        "Conic, 32 cones",
        n -> PCC.ConicPolyhedralTemplate(fill(PCC.planar_conic_partition(3), n)),
    ),
]

function bound(template, graph)
    time = @elapsed certificate =
        PCC.certify(template, graph, problem; optimizer = OPTIMIZER, rtol = RTOL)
    certificate.rate < RHO && @warn "bound $(certificate.rate) below rho(A_1) = $RHO"
    return certificate.rate, time
end

@printf("rho(A_1) = %.4f, a lower bound on the JSR\n\n", RHO)

# Warm-up, so that compilation does not count in the first time.
for (_, make) in TEMPLATES
    bound(make(1), first(GRAPHS)[2])
end

results = [
    (name, label, PCC.n_nodes(graph), bound(make(PCC.n_nodes(graph)), graph)...) for
    (name, make) in TEMPLATES for (label, graph) in GRAPHS
]

header =
    rpad("Template", 26) *
    join(rpad("$label ($(PCC.n_nodes(g)))", 22) for (label, g) in GRAPHS)
println(header)
println("-"^length(header))
for (name, _) in TEMPLATES
    row = filter(r -> r[1] == name, results)
    println(
        rpad(name, 26) *
        join(rpad(@sprintf("%.4f  (%.2f s)", r[4], r[5]), 22) for r in row),
    )
end

mkpath(joinpath(@__DIR__, "results"))
open(joinpath(@__DIR__, "results", "templates_jsr.csv"), "w") do io
    println(io, "template,graph,nodes,bound,time")
    for (name, label, nodes, rate, time) in results
        println(io, "\"$name\",$label,$nodes,$rate,$time")
    end
end
