# Figure "Automatic refinement" of the HSCC'27 tool paper (Section 5.2): the two
# refinement algorithms and the De Bruijn hierarchy on the same pair, with the
# quadratic template.
#
# Run from the repository root:
#
#     julia --project=numerical_experiments numerical_experiments/refinement.jl
#
# Prints, for each run, the time, size and bound of every graph visited, and the
# edges of the last refined graph; writes numerical_experiments/results/refinement.pdf.

import PathCompleteCertificates as PCC
import Clarabel, JuMP
using LinearAlgebra
using Plots

gr()
const OUT = joinpath(@__DIR__, "results")
mkpath(OUT)

# Categorical slots 1-3 of the validated reference palette, plus neutrals.
const BLUE = colorant"#2a78d6"
const ORANGE = colorant"#eb6834"
const AQUA = colorant"#1baf7a"
const INK = colorant"#52514e"
const GRID = colorant"#d9d8d4"

default(;
    fontfamily = "Computer Modern",
    titlefontsize = 9,
    guidefontsize = 8,
    tickfontsize = 7,
    legendfontsize = 7,
    linewidth = 1.5,
    framestyle = :box,
    grid = true,
    gridcolor = GRID,
    gridalpha = 0.6,
    foreground_color_legend = nothing,
    background_color_legend = RGBA(1, 1, 1, 0.85),
)

const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    # the chordal decomposition of Clarabel 0.11 fails on these programs
    "chordal_decomposition_enable" => false,
    "verbose" => false,
)
const TEMPLATE = PCC.QuadraticTemplate()

# ---------------------------------------------------------------------------
# Figure 2: automatic refinement versus De Bruijn graphs
# ---------------------------------------------------------------------------

A2 = [[1.631 0.793; 0.112 1.554], [0.287 0.366; 1.157 0.090]]
problem = PCC.StabilityProblem(PCC.switched_system(A2))
jsr = maximum(abs, eigvals(A2[1]))    # rho(A_1), attained: the JSR
println("rho(A_1) = ", jsr)

# Absolute slacks grow with the node functions: with the default atol = 1e-4,
# the chain edges of the 7-node graph read as slack and is_jsr_exact fires
# too early (OPTIMAL at a rate 7e-5 above the JSR). atol = 1e-3 reads them.
atol = 1e-3

# Wall-clock time at which each certificate of a run is reached: `stop` is
# called on every certificate, after the solves that produced it, the candidate
# solves of BestOfTightEdgeLifts included.
function timed_refine(algorithm; kwargs...)
    times = Float64[]
    t0 = time()
    trace = PCC.refine(
        TEMPLATE,
        problem;
        optimizer = OPTIMIZER,
        algorithm,
        atol,
        stop = c -> (push!(times, time() - t0); false),
        kwargs...,
    )
    return trace, times
end

# Warm-up, so that compilation is not timed.
timed_refine(PCC.TightestNodeSplitting(); depth_max = 2)
timed_refine(PCC.BestOfTightEdgeLifts(); depth_max = 2)
PCC.certify(TEMPLATE, PCC.de_bruijn(1, 2), problem; optimizer = OPTIMIZER)

runs = Dict(
    "tightest node splitting" =>
        timed_refine(PCC.TightestNodeSplitting(); depth_max = 12, stall_max = 3),
    "best of tight-edge lifts" =>
        timed_refine(PCC.BestOfTightEdgeLifts(); depth_max = 12, stall_max = 3),
)
for (name, (run, times)) in runs
    println("refine, $name: status = ", PCC.status(run))
    for (c, t) in zip(PCC.certificates(run), times)
        g = PCC.graph(c)
        println(
            "  ",
            round(t; digits = 2),
            " s  nodes $(PCC.n_nodes(g))  edges ",
            length(PCC.edges(g)),
            "  upper $(round(c.rate; digits = 6))  lower ",
            round(PCC.jsr_lower_bound(c; atol); digits = 6),
        )
    end
end
trace = first(runs["tightest node splitting"])

db_times, db_upper = Float64[], Float64[]
for order in 0:7
    g = order == 0 ? PCC.common_graph(problem.system) : PCC.de_bruijn(order, 2)
    # best of three: a single solve of a few hundredths of a second is noisy
    solve() = PCC.certify(TEMPLATE, g, problem; optimizer = OPTIMIZER, rtol = 1e-6)
    t = minimum(@elapsed(solve()) for _ in 1:3)
    c = solve()
    push!(db_times, t)
    push!(db_upper, c.rate)
    println(
        "  de_bruijn order $order: nodes $(PCC.n_nodes(g))  upper ",
        round(db_upper[end]; digits = 6),
        "  ",
        round(t; digits = 2),
        " s",
    )
end

fig2 = plot(;
    xlabel = "computation time (s)",
    ylabel = "upper bound on the JSR",
    xscale = :log10,
    ylims = (1.8875, 1.938),
    xlims = (0.03, 15),
    legend = :topright,
    size = (340, 220),
)
hline!(fig2, [jsr]; color = INK, lw = 1, ls = :dot, label = "JSR \$= \\rho(A_1)\$")
plot!(
    fig2,
    db_times,
    db_upper;
    color = ORANGE,
    marker = :rect,
    markersize = 4,
    markerstrokewidth = 0,
    label = "De Bruijn",
)
# The number of nodes of each graph, next to its point.
nodes_label(n, color, halign) = text(string(n), 6, color, halign)
for (t, r, order) in zip(db_times, db_upper, 0:7)
    # the first point sits on a vertical segment: label it on the left
    order == 0 ? annotate!(fig2, t / 1.12, r, nodes_label(1, ORANGE, :right)) :
    annotate!(fig2, t, r - 0.0025, nodes_label(2^order, ORANGE, :center))
end
for (name, ls, marker) in (
    ("tightest node splitting", :solid, :circle),
    ("best of tight-edge lifts", :dash, :diamond),
)
    run, times = runs[name]
    plot!(
        fig2,
        times,
        PCC.rates(run);
        color = BLUE,
        ls,
        marker,
        markersize = 4,
        markerstrokewidth = 0,
        label = name,
    )
    for (k, (t, r, g)) in enumerate(zip(times, PCC.rates(run), PCC.graphs(run)))
        # both runs start from the common graph: label it once
        k == 1 && name != "tightest node splitting" && continue
        annotate!(fig2, t * 1.1, r + 0.0013, nodes_label(PCC.n_nodes(g), BLUE, :left))
    end
end
savefig(fig2, joinpath(OUT, "refinement.pdf"))

# Edges of the last refined graph, tight ones marked, for the TikZ drawing.
last_certificate = last(PCC.certificates(trace))
g_last = PCC.graph(last_certificate)
tight = PCC.tight_edges(last_certificate; atol)
println("$(PCC.n_nodes(g_last))-node refined graph (tight edges marked *):")
for e in PCC.edges(g_last)
    s, d, i = PCC.source(e), PCC.dest(e), PCC.label(g_last, e)
    println("  $s -> $d  [$i] ", e in tight ? "*" : "")
end
