# Conic-template performance across the SetProg migration

Measured on 2026-11-03. This reproduces the stability case in
`ln/numerical_experiments` at `5c20b52`,
`numerical_experiments/templates_jsr.jl`: the two matrices beginning with
`A₁ = [1.631 0.793; 0.112 1.554]`, De Bruijn order 3 (8 nodes, 16 edges),
and `planar_conic_partition(3)` (32 cones over the full plane).

The regression is real. The requested SetProg/Polyhedra changes improve it,
but do not remove it. There is no PCC production-code change in this branch.

## Results

All cases use Julia 1.13.3, JuMP 1.32.1, MathOptInterface 1.54.0,
MutableArithmetics 1.9.3, Clarabel 0.11.1, and one BLAS thread.
Clarabel's absolute gap, relative gap, and feasibility tolerances are all
`1e-10`, exactly as in `templates_jsr.jl`. Times exclude package loading and
warm-up. Each bisection timing is one warmed run, so absolute times should
not be extrapolated to another machine.

| Implementation | PCC | SetProg | Polyhedra | Bisection, rtol=1e-3 | Bisection, rtol=1e-6 |
| --- | --- | --- | --- | ---: | ---: |
| Before SetProg migration | `37bac2e` | unused | unused | 2.45 s | 4.34 s |
| Previous SetProg dependencies | `048301a` | `b9740b8` | 0.8.2 | 31.05 s | 80.17 s |
| Requested fixes | `048301a` | `78a755f` (`bl/removeduplicates`) | 0.9.1 (`de1a2a8`) | 26.65 s | 70.75 s |
| Requested fixes, HiGHS for geometry | `048301a` | `78a755f` | 0.9.1 | not measured | 245.71 s |

At `rtol=1e-6`, every implementation returns `1.8947057723999023`.
At `rtol=1e-3`, every measured implementation returns `1.8955078125`.
The requested dependency fixes save approximately 12% at the experiment's
precision, but the result remains approximately 16 times slower than the
pre-migration implementation on this machine.

The old API defaulted to `rtol=1e-3`, whereas current `certify` defaults to
`1e-6`. That matters when comparing defaults, but does not explain the
regression above: the columns explicitly match the tolerance. The exact
experiment already supplies `rtol=1e-6`.

The following table separates construction from solving at the feasible
fixed rate `1.90`. It uses the faster of two warmed fixed-rate trials.
Expansion means translating deferred SetProg constraints to JuMP, before
calling the optimizer. Solve includes JuMP/MOI model transfer and the solver.
The counts are JuMP variables and constraint objects, including variable
bounds; vector constraints count as objects rather than scalar components.

| Implementation | Variables | Constraints | PCC construction | SetProg expansion | Solve |
| --- | ---: | ---: | ---: | ---: | ---: |
| Before migration | 264 | 25,096 | 0.0140 s | none | 0.0997 s |
| Previous dependencies | 95,488 | 119,808 | 0.0008 s | 0.7439 s | 1.4162 s |
| Requested fixes | 95,488 | 119,808 | 0.0009 s | 0.4619 s | 1.3935 s |
| Requested fixes, HiGHS for geometry | 5,888 | 7,680 | 0.0008 s | 10.4362 s | 0.0478 s |

The fixed-rate legacy solve reports `ALMOST_OPTIMAL`; the native SetProg
solves report `OPTIMAL`. The benchmark does not silently change PCC's policy
for accepting solver statuses.

## Explanation

The partition's adjacency graph reduces continuity/convexity constraints.
That does **not** imply that the complete optimization model is smaller.
`SetProg`'s generic piecewise inclusion compares every pair of pieces on the
intersection of their cones. Each nontrivial domain receives Farkas
multipliers and coefficient-matching constraints. Normalization also uses
piecewise inclusion. Many more variables are introduced than the original
PCC formulation, which compares linear pieces at the prescribed cone rays
without introducing those multipliers. The original symmetric formulation
stores half of the full-plane cones; the native family stores the full fan.
Normalization also differs, so these are equivalent bound computations on
this instance rather than identical LP matrices.

The experiment's partition has no Polyhedra solver. Consequently, linearity
preprocessing falls back to detecting opposite halfspaces; it cannot in
general identify a zero-dimensional cone intersection caused by three or
more halfspaces. Multipliers and equations for such intersections remain.
Repeated warnings about incomplete linearity detection are also expensive:
a profile of expansion with the requested fixes spends substantial time in
`removeduplicates`, `_detect_linearity`, and warning formatting.

As a diagnostic, providing a HiGHS-backed `DefaultLibrary` detects the
linearity and produces a much smaller LP. It instead solves many small
geometry LPs during every model expansion, making the full computation
slower still. This is not recommended as a performance workaround.

The remaining optimization belongs in SetProg's piecewise-linear inclusion
certificates: exploit the known partition/ray structure and avoid unnecessary
pairwise domains and multipliers. The smaller continuity model alone is not
sufficient evidence of an overall performance improvement. No specialized
PCC modeling fallback has been added here.

## Reproduction

Use each PCC checkout's `test/Project.toml` environment, with the dependency
versions in the table. Develop the requested SetProg branch and Polyhedra
v0.9.1 together, since resolving SetProg alone against an older registry can
fail before v0.9.1 is available there. Use the same MutableArithmetics version
for the historical environments as well.

The script below is the benchmark used for the exact-settings comparison.
It supports both PCC APIs, and prints cold and warmed fixed-model timings
separately. For the geometry diagnostic, set `CONIC_GEOMETRY_SOLVER=1`.
Set `CONIC_RTOLS=1e-3,1e-6` for both precision columns. Run the configurations
sequentially to avoid CPU contention. Standard warnings are left enabled;
their cost is included, as in the original experiment.

```julia
import PathCompleteCertificates as PCC
import SetProg
import Clarabel, HiGHS
import JuMP
import LinearAlgebra
import Profile

LinearAlgebra.BLAS.set_num_threads(1)
const SOLVER = get(ENV, "CONIC_SOLVER", "Clarabel") == "HiGHS" ? HiGHS.Optimizer :
    JuMP.optimizer_with_attributes(Clarabel.Optimizer, "verbose" => false,
        "tol_gap_abs" => 1e-10, "tol_gap_rel" => 1e-10, "tol_feas" => 1e-10)
const A = [[1.631 0.793; 0.112 1.554], [0.287 0.366; 1.157 0.090]]
const GRAPH = PCC.de_bruijn(3, 2)
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))
const PARTITION = if get(ENV, "CONIC_GEOMETRY_SOLVER", "0") == "1"
    PCC.planar_conic_partition(3; library = SetProg.Polyhedra.DefaultLibrary{Float64}(
        JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true)))
else
    PCC.planar_conic_partition(3)
end
const NATIVE = !(PARTITION isa AbstractVector)
const TEMPLATE = PCC.ConicPolyhedralTemplate(fill(PARTITION, PCC.n_nodes(GRAPH)))

function expand!(model)
    NATIVE || return
    data = SetProg.data(model)
    SetProg.set_space(data, model)
    SetProg.synchronize_perspective(data)
    SetProg.clear_spaces(data)
    SetProg.create_spaces(data)
    SetProg.load(model, data)
    return
end

function fixed()
    GC.gc()
    build = @timed PCC.optimization_model(TEMPLATE, GRAPH, PROBLEM; optimizer = SOLVER, rate = 1.90)
    model = build.value
    expand = @timed expand!(model)
    solve = @timed JuMP.optimize!(model; ignore_optimize_hook = true)
    return (
        build = build.time, expand = expand.time, solve = solve.time,
        bytes = build.bytes + expand.bytes + solve.bytes,
        variables = JuMP.num_variables(model),
        constraints = JuMP.num_constraints(model; count_variable_in_set_constraints = true),
        status = string(JuMP.termination_status(model)),
        solver = JuMP.solve_time(model),
    )
end

function bound(rtol)
    GC.gc()
    result = @timed if NATIVE
        PCC.certify(TEMPLATE, GRAPH, PROBLEM; optimizer = SOLVER, rtol)
    else
        PCC.jsr_bound(TEMPLATE, GRAPH, PROBLEM; optimizer = SOLVER, rtol)
    end
    return (seconds = result.time, bytes = result.bytes, rate = result.value.rate)
end

println("VERSIONS ", (julia = VERSION, pcc = pathof(PCC), setprog = pathof(SetProg), polyhedra = pkgversion(SetProg.Polyhedra), clarabel = pkgversion(Clarabel), native = NATIVE))
flush(stdout)
println("FIXED_COLD ", fixed()); flush(stdout)
for i in 1:2
    println("FIXED_WARM ", i, " ", fixed()); flush(stdout)
end
if get(ENV, "CONIC_PROFILE", "0") == "1"
    model = PCC.optimization_model(TEMPLATE, GRAPH, PROBLEM; optimizer = SOLVER, rate = 1.90)
    Profile.clear()
    Profile.@profile expand!(model)
    Profile.print(; format = :flat, sortedby = :count, mincount = 20)
    flush(stdout)
end
if get(ENV, "CONIC_SKIP_BISECTION", "0") != "1"
    for rtol in parse.(Float64, split(get(ENV, "CONIC_RTOLS", "1e-6"), ','))
        println("BOUND ", rtol, " ", bound(rtol)); flush(stdout)
    end
end

```
