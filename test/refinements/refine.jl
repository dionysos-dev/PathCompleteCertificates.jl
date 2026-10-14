module TestRefine

using Test
using HybridSystems
using Random
import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer
const TEMPLATE = PCC.QuadraticTemplate()

# A pure rotation scaled by 0.9: since rotations preserve the Euclidean norm
# exactly, P = I is already the exact quadratic certificate, at exactly the
# true JSR. Same trick as the conic-polyhedral tests.
theta = pi / 3
const ROTATED = 0.9 .* [cos(theta) -sin(theta); sin(theta) cos(theta)]

const ONE_NODE = GraphAutomaton(1)
add_transition!(ONE_NODE, 1, 1, 1)
const ONE_MODE_PROBLEM = PCC.StabilityProblem(PCC.switched_system([ROTATED]))

# A richer, two-mode system on the "complete" 2-node graph: opposite rotations
# of the same magnitude, so every node has two outgoing edges under two
# different dynamics rather than one.
theta2 = -pi / 3
const ROTATED2 = 0.9 .* [cos(theta2) -sin(theta2); sin(theta2) cos(theta2)]

const TWO_NODES = GraphAutomaton(2)
add_transition!(TWO_NODES, 1, 1, 1)
add_transition!(TWO_NODES, 1, 2, 2)
add_transition!(TWO_NODES, 2, 1, 1)
add_transition!(TWO_NODES, 2, 2, 2)
const TWO_MODE_PROBLEM = PCC.StabilityProblem(PCC.switched_system([ROTATED, ROTATED2]))

# A rotation and a shear, both scaled by 0.69: no quadratic function attains the
# joint spectral radius of this pair, so the memoryless bound is loose and there
# is something for refinement to win. Same system as the SOS example.
const SHEARED = PCC.StabilityProblem(
    PCC.switched_system([0.69 .* [0.0 1.0; -1.0 0.0], 0.69 .* [1.0 1.0; 0.0 1.0]]),
)

const MEMORYLESS = GraphAutomaton(1)
add_transition!(MEMORYLESS, 1, 1, 1)
add_transition!(MEMORYLESS, 1, 1, 2)

@testset "a node with a single outgoing edge always converges immediately" begin
    trace = PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 3,
    )

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
    # than through the gap check -- the status tells the two apart.
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

@testset "refine only ever holds or tightens the certified rate as it lifts" begin
    trace = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 3,
    )

    @test length(PCC.graphs(trace)) == length(PCC.rates(trace))

    # Never below the true JSR, and lifting never makes the bound worse: any
    # certificate feasible before a lift stays feasible after it (every copy
    # of the lifted node just inherits its function), so the bisected rate
    # can only go down or stay put.
    @test all(>=(0.9 - 1e-2), PCC.rates(trace))
    @test issorted(PCC.rates(trace); rev = true)
    @test issorted(PCC.n_nodes.(PCC.graphs(trace)))

    # The last graph visited still carries a genuine certificate, independent
    # of the bookkeeping inside `refine` itself.
    final = PCC.jsr_bound(
        TEMPLATE,
        PCC.graphs(trace)[end],
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
    )
    @test PCC.is_feasible(final)
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

    # Optimal control has no objective or edge slacks to read, and says so
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
    # From the initial graph of Ninite & Jungers' algorithm, the dual De Bruijn
    # graph of order 1.
    trace = PCC.refine(TEMPLATE, SHEARED; optimizer = OPTIMIZER, depth_max = 3)

    rates = PCC.rates(trace)

    # Deterministic without a seed, which is the point: ties go to the cheapest
    # split, so this trajectory is the same on every Julia version. Seeding an
    # `rng` would NOT give that -- `rand(rng, ::Vector)` may sample differently
    # between versions, and this assertion failed on 1.10 while passing on 1.12.
    @test PCC.n_nodes.(PCC.graphs(trace)) == [2, 3, 4]

    # The point of the whole loop: the bound genuinely falls, not merely fails to
    # rise. Anything weaker is satisfied by a lift that does nothing.
    @test all(<(0), diff(rates))

    # On this system the dual De Bruijn graph of order 1 certifies the rate of
    # De Bruijn of order 1; four nodes reached by lifting is *not* De Bruijn of
    # order 2, and is strictly better than it.
    memory_1 = PCC.jsr_bound(TEMPLATE, PCC.de_bruijn(1, 2), SHEARED; optimizer = OPTIMIZER)
    memory_2 = PCC.jsr_bound(TEMPLATE, PCC.de_bruijn(2, 2), SHEARED; optimizer = OPTIMIZER)

    @test isapprox(rates[1], memory_1.rate; rtol = 1e-3)
    @test rates[3] < memory_2.rate

    # An explicit rng still breaks the remaining ties, and still refines.
    random = PCC.refine(
        TEMPLATE,
        SHEARED;
        optimizer = OPTIMIZER,
        depth_max = 3,
        algorithm = PCC.TightNodeSplitting(; rng = MersenneTwister(1)),
    )

    @test all(<(0), diff(PCC.rates(random)))
end

@testset "the trace carries the certificates, not only the bounds" begin
    trace = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 2,
    )

    every = PCC.certificates(trace)

    @test length(every) == length(PCC.graphs(trace))
    @test all(PCC.is_feasible, every)
    @test [c.rate for c in every] == PCC.rates(trace)

    # The Lyapunov functions are there, so a run can be drawn without re-solving.
    @test all(c -> c([1.0, 1.0]) > 0, every)
end

@testset "an exact certificate is certified, not ground down" begin
    # ROTATED and ROTATED2 are rotations scaled by 0.9, so P = I is EXACT and the
    # JSR is exactly 0.9 on any graph. Every edge is therefore tight, every node
    # always looks splittable, and Theorem 4 can never fire -- measured before
    # the bracket existed: 2, 3, 5, 7, 10 nodes over five identical bounds.
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

    # With the bracket switched off -- `gap_tol` below zero can never be met --
    # the same system exercises the stall path on its own: it grows at a
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

@testset "the status tells the outcomes apart" begin
    # One mode, one tight self-loop: Theorem 4's condition holds, and the cycle
    # through that self-loop meets the rate. Certified either way.
    @test PCC.status(
        PCC.refine(
            TEMPLATE,
            ONE_NODE,
            ONE_MODE_PROBLEM;
            optimizer = OPTIMIZER,
            depth_max = 3,
        ),
    ) == PCC.OPTIMAL

    @test PCC.status(
        PCC.refine(
            TEMPLATE,
            ONE_NODE,
            ONE_MODE_PROBLEM;
            optimizer = OPTIMIZER,
            depth_max = 3,
            stop = c -> c.rate < 1,
        ),
    ) == PCC.STOPPED

    @test PCC.status(
        PCC.refine(
            TEMPLATE,
            SHEARED;
            optimizer = OPTIMIZER,
            depth_max = 2,
            algorithm = PCC.TightNodeSplitting(),
        ),
    ) == PCC.DEPTH_REACHED

    # The one-node graph: both loops are tight, but its only successor is
    # itself, so the forward lift would change nothing and no node is left.
    exhausted = PCC.refine(TEMPLATE, MEMORYLESS, SHEARED; optimizer = OPTIMIZER)
    @test PCC.status(exhausted) == PCC.EXHAUSTED
    @test length(PCC.graphs(exhausted)) == 1
end

@testset "path_complete decides the starting graph, and the refinements are trusted after it" begin
    settings = (optimizer = OPTIMIZER, depth_max = 3, algorithm = PCC.TightNodeSplitting())
    start = PCC.dual(PCC.de_bruijn(1, 2))

    # Waiving the check cannot change the answer on a graph that has the
    # property -- it only skips deciding it.
    checked = PCC.refine(TEMPLATE, start, SHEARED; settings..., path_complete = true)
    waived = PCC.refine(TEMPLATE, start, SHEARED; settings..., path_complete = false)

    @test PCC.rates(checked) == PCC.rates(waived)
    @test PCC.n_nodes.(PCC.graphs(checked)) == PCC.n_nodes.(PCC.graphs(waived))

    # Which is the half the loop relies on: preservation. Skipping the recheck is
    # only sound because every lift of a path-complete graph is path-complete,
    # and that is asserted here rather than at run time.
    @test all(graph -> PCC.is_path_complete(graph, 1:2), PCC.graphs(waived))

    # The starting graph, though, is still decided -- node 2 has no outgoing edge, so no
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
        depth_max = 2,
        rtol = 1e-6,
        atol = 1e-5,
    )

    @test PCC.n_nodes.(PCC.graphs(decade)) == [2, 3]
end

@testset "every local lift at every tight edge, best candidate, parallel-faces template" begin
    # Athanasopoulos & Jungers, Example 2, on the plane: the four partial lifts
    # at every tight edge, each candidate solved, the best kept. The products
    # write words on the edges, so the graph gains edges rather than nodes.
    problem = SHEARED
    template = PCC.ParallelFacesPolyhedralTemplate(1, 2)

    trace = PCC.refine(
        template,
        MEMORYLESS,
        problem;
        optimizer = OPTIMIZER,
        algorithm = PCC.BestTightEdgeLifting(),
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
        step -> length(PCC.origins(step)) == PCC.n_nodes(PCC.graph(step)),
        PCC.steps(trace),
    )
    @test all(
        c -> length(PCC.functions(c)) == PCC.n_nodes(PCC.graph(c)),
        PCC.certificates(trace),
    )

    # The final certificate stands on its own, on whatever graph was reached.
    final = PCC.certificates(trace)[end]
    @test PCC.is_feasible(final)
    @test PCC.is_path_complete(PCC.graph(final), 1:2)
end

@testset "the loop runs on a safety problem and the margin never falls" begin
    S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
    Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]
    modes = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
    safety = PCC.SafetyProblem(PCC.switched_system(modes), S0, Su)

    trace = PCC.refine(
        TEMPLATE,
        PCC.de_bruijn(1, 2),
        safety;
        optimizer = OPTIMIZER,
        depth_max = 3,
    )

    margins = [certificate.margin for certificate in PCC.certificates(trace)]
    @test PCC.objective.(PCC.certificates(trace)) == -margins
    @test all(>=(-1e-6), diff(margins))
    @test PCC.status(trace) in (PCC.STALLED, PCC.DEPTH_REACHED, PCC.EXHAUSTED)
    @test all(
        c -> length(PCC.edge_slacks(c)) == PCC.n_edges(PCC.graph(c)),
        PCC.certificates(trace),
    )
end

@testset "a hierarchy applies one lift to the whole graph at every step" begin
    # One path-dependent step from the one-node graph each time: De Bruijn of
    # growing order, so the rates are those of de_bruijn(k, 2).
    trace = PCC.refine(
        TEMPLATE,
        SHEARED;
        optimizer = OPTIMIZER,
        algorithm = PCC.Hierarchy(PCC.PathDependentLift(1)),
        depth_max = 3,
    )

    @test PCC.n_nodes.(PCC.graphs(trace)) == [1, 2, 4]
    for (k, certificate) in enumerate(PCC.certificates(trace)[2:end])
        db = PCC.jsr_bound(
            TEMPLATE,
            PCC.de_bruijn(k, 2),
            SHEARED;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
        )
        @test isapprox(certificate.rate, db.rate; rtol = 1e-4)
    end
end

@testset "a lift as the step is accepted where it is valid and refused where not" begin
    # Jongeneel & Jungers, §IV-A: the forward composition lift refines a graph
    # for a template closed under composition with invertible dynamics.
    composition = PCC.Hierarchy(PCC.CompositionLift(1))
    trace = PCC.refine(
        TEMPLATE,
        SHEARED;
        optimizer = OPTIMIZER,
        algorithm = composition,
        depth_max = 2,
    )
    @test PCC.n_nodes.(PCC.graphs(trace)) == [1, 2]
    @test PCC.rates(trace)[2] <= PCC.rates(trace)[1] * (1 + 1e-4)

    # Refused on a singular system, and on a template not closed under
    # composition, the moment the step is asked for.
    singular =
        PCC.StabilityProblem(PCC.switched_system([[0.5 0.0; 0.0 0.0], [0.0 0.5; 0.5 0.0]]))
    on_singular = PCC.jsr_bound(TEMPLATE, MEMORYLESS, singular; optimizer = OPTIMIZER)
    @test_throws ArgumentError PCC.next_graph(
        composition,
        on_singular;
        atol = 1e-4,
        solve = identity,
    )

    polyhedral = PCC.jsr_bound(
        PCC.ParallelFacesPolyhedralTemplate(1, 2),
        MEMORYLESS,
        SHEARED;
        optimizer = OPTIMIZER,
    )
    @test_throws ArgumentError PCC.next_graph(
        composition,
        polyhedral;
        atol = 1e-4,
        solve = identity,
    )
end

end # module
