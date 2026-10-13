# Test driver.
#
# Fast dev loop: `Pkg.test(; test_args = ["--fast"])` skips suites tagged `:slow` — the
# SDP- and LP-heavy synthesis suites, whose coverage is not worth the wall-clock while
# iterating. A plain `Pkg.test()` and CI run everything. Each file's run time is printed,
# with a slowest-first summary, so a suite that has grown expensive is easy to spot and tag.
const FAST_TESTS = "--fast" in ARGS

# (path, tags...). Tag a suite `:slow` to exclude it from `--fast`.
const TEST_FILES = [
    ("./aqua.jl", :slow),  # quality gate: piracy, ambiguities, stale deps
    ("./docstrings.jl",),  # every reachable name has a docstring
    ("./graphs/queries.jl",),
    ("./graphs/path_completeness.jl",),
    ("./graphs/de_bruijn.jl",),
    ("./graphs/observer.jl",),
    ("./graphs/cycles.jl",),
    ("./graphs/words.jl",),
    ("./lifts/split.jl",),
    ("./lifts/reference.jl",),
    ("./lifts/product.jl", :slow),
    ("./lifts/identity.jl",),
    ("./lifts/min.jl",),
    ("./lifts/sum.jl", :slow),
    ("./lifts/composition.jl",),
    ("./systems/switched.jl",),
    ("./systems/trajectory.jl",),
    ("./systems/simulate.jl",),
    ("./templates/parallel_faces_polyhedral.jl", :slow),
    ("./templates/conic_polyhedral.jl", :slow),
    ("./templates/sum_of_squares.jl", :slow),
    ("./templates/set_prog.jl", :slow),
    ("./problems/certify.jl", :slow),
    ("./problems/tight_edges.jl", :slow),
    ("./problems/stability.jl", :slow),
    ("./problems/safety.jl",),
    ("./problems/optimal_control.jl", :slow),
    ("./problems/certificate.jl", :slow),
    ("./problems/dual.jl", :slow),
    ("./problems/common.jl",),
    ("./lifts/compare.jl", :slow),
    ("./refinements/refine.jl", :slow),
]

const _timings = Tuple{String, Float64}[]
for entry in TEST_FILES
    path = entry[1]
    tags = entry[2:end]
    if FAST_TESTS && (:slow in tags)
        println("[skip] ", path)
        continue
    end
    dt = @elapsed include(path)
    println("[time] ", lpad(string(round(dt; digits = 1)), 7), "s  ", path)
    push!(_timings, (path, dt))
end

println("\n===== Test file timings (slowest first) =====")
for (path, sec) in sort(_timings; by = x -> -x[2])
    println(lpad(string(round(sec; digits = 1)), 8), "s  ", path)
end
println(
    "total: ",
    round(sum(last, _timings; init = 0.0); digits = 1),
    "s over ",
    length(_timings),
    " files",
)
