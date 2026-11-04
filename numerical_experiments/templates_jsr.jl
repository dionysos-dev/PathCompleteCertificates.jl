# Table "Stability and safety for several templates and graphs" of the HSCC'27
# tool paper (Section 5.1): the pair of Section 5.2, six templates on the common
# graph and on the De Bruijn graphs of order 1 and 3.
#
# Run from the repository root:
#
#     julia --project=numerical_experiments -e 'using Pkg; Pkg.instantiate()'
#     julia --project=numerical_experiments numerical_experiments/templates_jsr.jl
#
# Stability: the upper bound on the JSR. The lower bound rho(A_1) is the JSR on
# this pair; a bound below it signals a solver tolerance too loose.
#
# Safety: the pair scaled by 1/2, so that its trajectories stay bounded, with
# the initial set X0 = {x : ||x|| <= 4}. Bisection finds the smallest R such
# that safety is certified for the unsafe set Xu = {x : ||x|| >= R}: every
# trajectory from X0 stays in the ball of radius R. The lower bound is R0 times
# the largest norm of a product of mode matrices: no certificate can do better.
# The polyhedral templates need SetProg.jl at its main branch, see the README.
#
# Prints both tables, with the time of each solve, and writes them to
# numerical_experiments/results/templates_jsr.csv and templates_safety.csv.

import PathCompleteCertificates as PCC
import Clarabel, HiGHS, JuMP, SetProg
using SumOfSquares
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
# with the tolerances above, some piecewise quadratic programs end without a
# solution, and the bisection then overestimates the bound
const PIECEWISE_QUADRATIC_OPTIMIZER =
    JuMP.optimizer_with_attributes(Clarabel.Optimizer, "verbose" => false)
const SAFETY_OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    # the chordal decomposition of Clarabel 0.11 fails on these programs
    "chordal_decomposition_enable" => false,
    "verbose" => false,
)
const RTOL = 1e-6

A = [[1.631 0.793; 0.112 1.554], [0.287 0.366; 1.157 0.090]]
problem = PCC.StabilityProblem(PCC.switched_system(A))
const RHO = maximum(abs, eigvals(A[1]))

# Safety data: the scaled pair, the initial set, the unsafe sets, the largest R
# tried and the relative precision of the bisection.
const A_SAFETY = A ./ 2
safe_system = PCC.switched_system(A_SAFETY)
const R0 = 4.0
const S0 = [-1.0 0 0; 0 -1.0 0; 0 0 R0^2]   # ||x|| <= R0
unsafe(R) = [1.0 0 0; 0 1.0 0; 0 0 -R^2]    # ||x|| >= R
const R_MAX = 100.0
const R_RTOL = 1e-4

const GRAPHS = [
    ("Common", PCC.common_graph(problem.system)),
    ("De Bruijn 1", PCC.de_bruijn(1, 2)),
    ("De Bruijn 3", PCC.de_bruijn(3, 2)),
]

# The cones of the piecewise templates: 16 for the piecewise quadratic one, 32
# for the piecewise linear one. The linear programming solver lets Polyhedra
# detect the linearity of the pieces.
const LIBRARY = SetProg.Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)
const CONES_16 = PCC.planar_conic_partition(2; library = LIBRARY)
const CONES_32 = PCC.planar_conic_partition(3; library = LIBRARY)

# The polyhedral and piecewise templates carry data per node, hence are built
# for each graph. Each template comes with the optimizer of its stability
# solves, and the last field says whether it supports safety.
const TEMPLATES = [
    ("Quadratic", n -> PCC.QuadraticTemplate(), OPTIMIZER, true),
    (
        "Piecewise quadratic, 16 cones",
        n -> PCC.PiecewiseQuadraticTemplate(fill(CONES_16, n)),
        PIECEWISE_QUADRATIC_OPTIMIZER,
        false,
    ),
    ("Sum of squares, r = 2", n -> PCC.SumOfSquaresTemplate(2), OPTIMIZER, true),
    ("Sum of squares, r = 3", n -> PCC.SumOfSquaresTemplate(3), OPTIMIZER, true),
    (
        "Piecewise linear, 32 cones",
        n -> PCC.PiecewiseLinearTemplate(fill(CONES_32, n)),
        OPTIMIZER,
        true,
    ),
    (
        "Parallel faces, F_s = I",
        n -> PCC.DualPiecewiseLinearTemplate(n, 2),
        OPTIMIZER,
        true,
    ),
]

function bound(template, graph, optimizer)
    time =
        @elapsed certificate = PCC.certify(template, graph, problem; optimizer, rtol = RTOL)
    certificate.rate < RHO && @warn "bound $(certificate.rate) below rho(A_1) = $RHO"
    return certificate.rate, time
end

function certified(template, graph, R)
    safety = PCC.SafetyProblem(safe_system, S0, unsafe(R))
    certificate = PCC.certify(template, graph, safety; optimizer = SAFETY_OPTIMIZER)
    return PCC.is_feasible(certificate)
end

# Smallest certified radius, or Inf if none up to R_MAX, and the time of one
# certificate at that radius.
function radius(template, graph)
    certified(template, graph, R_MAX) || return Inf, NaN
    lo, hi = R0, R_MAX
    while hi - lo > R_RTOL * hi
        mid = (lo + hi) / 2
        certified(template, graph, mid) ? (hi = mid) : (lo = mid)
    end
    time = @elapsed certified(template, graph, hi)
    return hi, time
end

# R0 times the largest norm of the products of length at most L, attained by
# trajectories from X0.
function radius_lower_bound(L)
    best, layer = 1.0, [Matrix(1.0I, 2, 2)]
    for _ in 1:L
        layer = [Ai * P for P in layer for Ai in A_SAFETY]
        best = max(best, maximum(opnorm, layer))
    end
    return R0 * best
end

function print_table(results, format)
    header =
        rpad("Template", 32) *
        join(rpad("$label ($(PCC.n_nodes(g)))", 22) for (label, g) in GRAPHS)
    println(header)
    println("-"^length(header))
    for (name, _) in TEMPLATES
        row = filter(r -> r[1] == name, results)
        println(
            rpad(name, 32) *
            join(rpad(@sprintf("%s  (%.2f s)", format(r[4]), r[5]), 22) for r in row),
        )
    end
    return println()
end

function write_csv(file, quantity, results)
    mkpath(joinpath(@__DIR__, "results"))
    open(joinpath(@__DIR__, "results", file), "w") do io
        println(io, "template,graph,nodes,$quantity,time")
        for (name, label, nodes, value, time) in results
            println(io, "\"$name\",$label,$nodes,$value,$time")
        end
    end
end

# Warm-up, so that compilation does not count in the times.
for (_, make, optimizer, has_safety) in TEMPLATES
    template = make(1)
    graph = first(GRAPHS)[2]
    bound(template, graph, optimizer)
    has_safety && certified(template, graph, R_MAX)
end

# Stability.
@printf("Stability: rho(A_1) = %.4f, a lower bound on the JSR\n\n", RHO)
stability = [
    (name, label, PCC.n_nodes(graph), bound(make(PCC.n_nodes(graph)), graph, optimizer)...) for (name, make, optimizer) in TEMPLATES for (label, graph) in GRAPHS
]
print_table(stability, v -> @sprintf("%.4f", v))
write_csv("templates_jsr.csv", "bound", stability)

# Safety, NaN for a template that does not support it.
@printf("Safety: %.4f, a lower bound on the radius\n\n", radius_lower_bound(16))
safety = [
    (
        name,
        label,
        PCC.n_nodes(graph),
        (has_safety ? radius(make(PCC.n_nodes(graph)), graph) : (NaN, NaN))...,
    ) for (name, make, _, has_safety) in TEMPLATES for (label, graph) in GRAPHS
]
print_table(safety, v -> @sprintf("%.4f", v))
write_csv("templates_safety.csv", "radius", safety)
