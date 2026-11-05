module TestRefine

using Test
using HybridSystems
using Random
import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra

const OPTIMIZER = Clarabel.Optimizer
const TEMPLATE = PCC.QuadraticTemplate()

rotation(angle) = [cos(angle) -sin(angle); sin(angle) cos(angle)]

# A pure rotation scaled by 0.9: since rotations preserve the Euclidean norm
# exactly, P = I is already the exact quadratic certificate, at exactly the
# true JSR.
const ROTATED = 0.9 .* rotation(pi / 3)

const ONE_NODE = PCC.common_graph(1)
const ONE_MODE_PROBLEM = PCC.StabilityProblem(PCC.switched_system([ROTATED]))

# A richer, two-mode system on the complete 2-node graph: opposite rotations
# of the same magnitude, so every node has two outgoing edges under two
# different dynamics rather than one.
const ROTATED2 = 0.9 .* rotation(-pi / 3)

const TWO_NODES = PCC.de_bruijn(1, 2)
const TWO_MODE_PROBLEM = PCC.StabilityProblem(PCC.switched_system([ROTATED, ROTATED2]))

# A rotation and a shear, both scaled by 0.69: no quadratic function attains the
# joint spectral radius of this pair, so the memoryless bound is loose and there
# is something for refinement to win.
const SHEARED = PCC.StabilityProblem(
    PCC.switched_system([0.69 .* [0.0 1.0; -1.0 0.0], 0.69 .* [1.0 1.0; 0.0 1.0]]),
)

const MEMORYLESS = PCC.common_graph(2)

@testset "a node with a single outgoing edge always converges immediately" begin
    trace = PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 3,
    )

    @test PCC.get_template(first(PCC.certificates(trace))) == TEMPLATE
    @test PCC.status(trace) == PCC.OPTIMAL
    @test length(PCC.graphs(trace)) == 1
    @test length(PCC.rates(trace)) == 1
    @test isapprox(PCC.rates(trace)[1], 0.9; atol = 1e-3)
end

@testset "stop ends the loop before convergence is even checked" begin
    trace = PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 3,
        stop = c -> c.rate < 1,
    )

    # The certified rate is already < 1, so this exits through `stop` rather
    # than through the gap check, and the status tells the two apart.
    @test PCC.status(trace) == PCC.STOPPED
    @test length(PCC.graphs(trace)) == 1
    @test PCC.rates(trace)[1] < 1
end

@testset "depth_max stops the loop without claiming convergence" begin
    # On a system the starting graph does not already solve: the rotations are certified
    # optimal at the first step, so `depth_max` would not be why that run ended.
    trace = PCC.refine(TEMPLATE, MEMORYLESS, SHEARED; optimizer = OPTIMIZER, depth_max = 1)

    @test PCC.status(trace) == PCC.DEPTH_REACHED
    @test length(PCC.graphs(trace)) == 1
    @test length(PCC.rates(trace)) == 1
end

@testset "input validation" begin
    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 0,
    )

    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        stall_max = 0,
    )

    # Only stability defines an objective, so refine refuses the other problems
    # before solving anything.
    controlled = PCC.switched_system([ROTATED], [reshape([1.0, 0.0], 2, 1)])
    control = PCC.OptimalControlProblem(controlled, [1.0 0.0; 0.0 1.0], [1.0;;])
    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        ONE_NODE,
        control;
        optimizer = OPTIMIZER,
    )
end

@testset "refinement beats De Bruijn node for node" begin
    # From the one-node graph, whose first split is the dual De Bruijn graph of
    # order 1.
    trace = PCC.refine(TEMPLATE, SHEARED; optimizer = OPTIMIZER, depth_max = 4)

    rates = PCC.rates(trace)

    # Deterministic without a seed, which is the point: ties go to the cheapest
    # split, so this trajectory is the same on every Julia version. Seeding an
    # `rng` would not give that, since `rand(rng, ::Vector)` may sample
    # differently between versions.
    @test PCC.n_nodes.(PCC.graphs(trace)) == [1, 2, 3, 4]

    # The one-node graph: both loops are tight, and its out-splitting, one
    # copy per loop, is the dual De Bruijn graph of order 1.
    @test PCC.origins(first(PCC.steps(trace))) == [1, 1]

    # The point of the whole loop: the bound genuinely falls, not merely fails to
    # rise. Anything weaker is satisfied by a lift that does nothing.
    @test all(<(0), diff(rates))

    # On this system the dual De Bruijn graph of order 1 certifies the rate of
    # De Bruijn of order 1. The four nodes reached by lifting are *not* De Bruijn
    # of order 2, and are strictly better than it.
    memory_1 = PCC.certify(TEMPLATE, PCC.de_bruijn(1, 2), SHEARED; optimizer = OPTIMIZER)
    memory_2 = PCC.certify(TEMPLATE, PCC.de_bruijn(2, 2), SHEARED; optimizer = OPTIMIZER)

    @test isapprox(rates[2], memory_1.rate; rtol = 1e-3)
    @test rates[4] < memory_2.rate

    # An explicit rng still breaks the remaining ties, and still refines.
    random = PCC.refine(
        TEMPLATE,
        SHEARED;
        optimizer = OPTIMIZER,
        depth_max = 3,
        strategy = PCC.TightestNodeSplitting(; rng = MersenneTwister(1)),
    )

    @test all(<(0), diff(PCC.rates(random)))
end

@testset "the trace carries the certificates, not only the bounds" begin
    trace = PCC.refine(TEMPLATE, MEMORYLESS, SHEARED; optimizer = OPTIMIZER, depth_max = 3)

    every = PCC.certificates(trace)

    @test length(every) == 3
    @test all(PCC.is_feasible, every)

    # The Lyapunov functions are there, so a run can be drawn without re-solving.
    @test all(c -> c([1.0, 1.0]) > 0, every)
end

@testset "an exact certificate is certified, not ground down" begin
    # ROTATED and ROTATED2 are rotations scaled by 0.9, so P = I is EXACT and the
    # JSR is exactly 0.9 on any graph. Every edge is therefore tight, every node
    # always looks splittable, and Theorem 4 can never fire.
    #
    # The cycle bound closes it on the first step instead: both modes are
    # rotations of norm 0.9, so some cycle attains the rate exactly.
    trace = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 5,
    )

    @test PCC.status(trace) == PCC.OPTIMAL
    @test length(PCC.graphs(trace)) == 1     # certified without lifting at all
    @test all(rate -> isapprox(rate, 0.9; atol = 1e-3), PCC.rates(trace))

    # Certified means bracketed: the lower bound meets the rate.
    @test PCC.rates(trace)[end] -
          PCC.jsr_lower_bound(PCC.certificates(trace)[end]; atol = 1e-4) < 1e-4

    # And Theorem 4 alone would not have seen it.
    @test !PCC.is_jsr_exact(PCC.certificates(trace)[end]; atol = 1e-4)

    # With the bracket switched off, since `gap_tol` below zero can never be
    # met, the same system exercises the stall path on its own: it grows at a
    # constant bound until `stall_max` says stop.
    stalling = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 5,
        gap_tol = -1.0,
    )

    @test PCC.status(stalling) == PCC.STALLED
    @test length(PCC.graphs(stalling)) == 2

    # And the knob that lets a greedy search cross a plateau, at one bisection
    # per extra step.
    patient = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 5,
        gap_tol = -1.0,
        stall_max = 3,
    )

    @test PCC.status(patient) == PCC.STALLED
    @test length(PCC.graphs(patient)) == 4
end

@testset "check_path_complete decides the starting graph, and the refinements are trusted after it" begin
    settings =
        (optimizer = OPTIMIZER, depth_max = 3, strategy = PCC.TightestNodeSplitting())
    start = PCC.dual(PCC.de_bruijn(1, 2))

    # Waiving the check cannot change the answer on a graph that has the
    # property, since it only skips deciding it.
    checked = PCC.refine(TEMPLATE, start, SHEARED; settings..., check_path_complete = true)
    waived = PCC.refine(TEMPLATE, start, SHEARED; settings..., check_path_complete = false)

    @test PCC.rates(checked) == PCC.rates(waived)
    @test PCC.n_nodes.(PCC.graphs(checked)) == PCC.n_nodes.(PCC.graphs(waived))

    # Which is the half the loop relies on: preservation. Skipping the recheck is
    # only sound because every lift of a path-complete graph is path-complete,
    # and that is asserted here rather than at run time.
    @test all(graph -> PCC.is_path_complete(graph, 1:2), PCC.graphs(waived))

    # The starting graph, though, is still decided. Node 2 has no outgoing edge, so no
    # word ending in mode 2 is readable.
    dead_end = GraphAutomaton(2)
    add_transition!(dead_end, 1, 1, 1)
    add_transition!(dead_end, 1, 2, 2)

    @test !PCC.is_path_complete(dead_end, 1:2)
    @test_throws ArgumentError PCC.refine(TEMPLATE, dead_end, SHEARED; settings...)
end

@testset "the tightness tolerance must clear the bisection residual by a decade" begin
    # Below a decade the tight subgraph can come out empty: the starting graph's
    # two self-loops measure 2.9e-6 and 3.5e-6 at rtol = 1e-6, so an atol of
    # 2e-6 sees neither and the run would stop with nothing to split.
    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        MEMORYLESS,
        SHEARED;
        optimizer = OPTIMIZER,
        rtol = 1e-6,
        atol = 2e-6,
    )

    # Exactly a decade is accepted, and still finds the edges.
    decade = PCC.refine(
        TEMPLATE,
        SHEARED;
        optimizer = OPTIMIZER,
        depth_max = 3,
        rtol = 1e-6,
        atol = 1e-5,
    )

    @test PCC.n_nodes.(PCC.graphs(decade)) == [1, 2, 3]
end

@testset "every local lift at every tight edge, best candidate, dual piecewise linear template" begin
    # Athanasopoulos & Jungers, Example 2, on the plane: the four partial lifts
    # at every tight edge, each candidate solved, the best kept. The products
    # write words on the edges, so the graph gains edges rather than nodes.
    problem = SHEARED
    template = PCC.DualPiecewiseLinearTemplate(1, 2)

    trace = PCC.refine(
        template,
        MEMORYLESS,
        problem;
        optimizer = OPTIMIZER,
        strategy = PCC.BestOfTightEdgeLifts(),
        depth_max = 4,
        atol = 1e-4,
    )

    bounds = PCC.objective.(PCC.certificates(trace))
    @test length(bounds) >= 2
    @test issorted(bounds; rev = true)
    @test bounds[end] < bounds[1]

    # Each step is recorded with its provenance, and the template followed it.
    @test length(PCC.steps(trace)) == length(bounds) - 1
    @test all(
        step -> length(PCC.origins(step)) == PCC.n_nodes(PCC.get_graph(step)),
        PCC.steps(trace),
    )
    @test all(
        c -> length(PCC.functions(c)) == PCC.n_nodes(PCC.get_graph(c)),
        PCC.certificates(trace),
    )

    # The final certificate stands on its own, on whatever graph was reached.
    final = PCC.certificates(trace)[end]
    @test PCC.is_feasible(final)
    @test PCC.is_path_complete(PCC.get_graph(final), 1:2)
end

@testset "the loop refuses a safety problem" begin
    S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
    Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]
    modes = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
    safety = PCC.SafetyProblem(PCC.switched_system(modes), S0, Su)

    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        PCC.de_bruijn(1, 2),
        safety;
        optimizer = OPTIMIZER,
    )
end

@testset "a large normalization does not hide the tight edges" begin
    # The running example of the manual: its node functions come out with
    # eigenvalues in the hundreds, which made absolute slacks of tight edges
    # exceed `atol`. Relative slacks see them, and Thm. 4 proves the rate exact.
    A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
    problem = PCC.StabilityProblem(PCC.switched_system(A))
    trace = PCC.refine(TEMPLATE, problem; optimizer = OPTIMIZER)

    jsr = maximum(abs, LinearAlgebra.eigvals(A[1] * A[1] * A[2]))^(1 / 3)
    @test PCC.status(trace) == PCC.OPTIMAL
    @test isapprox(last(PCC.rates(trace)), jsr; atol = 1e-5)
    @test PCC.is_jsr_exact(last(PCC.certificates(trace)))
end

end # module
