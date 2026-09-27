module TestRefinementStability

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

@testset "a node with a single outgoing edge always converges immediately" begin
    trace = PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 3,
    )

    @test PCC.is_converged(trace)
    @test length(PCC.graphs(trace)) == 1     # nothing to lift, so no lift happened
    @test length(PCC.rates(trace)) == 1
    @test isapprox(PCC.rates(trace)[1], 0.9; atol = 1e-3)
end

@testset "until_stability stops the loop before convergence is even checked" begin
    trace = PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 3,
        until_stability = true,
    )

    # The certified rate is already < 1, so this exits through the
    # `until_stability` branch rather than the "nothing left to tighten"
    # branch -- `is_converged` tells the two apart.
    @test !PCC.is_converged(trace)
    @test length(PCC.graphs(trace)) == 1
    @test PCC.rates(trace)[1] < 1
end

@testset "depth_max stops the loop without claiming convergence" begin
    trace = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 1,
    )

    @test !PCC.is_converged(trace)
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

    @test PCC.is_converged(trace) isa Bool
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
end

# A rotation and a shear, both scaled by 0.69: no quadratic function attains the
# joint spectral radius of this pair, so the memoryless bound is loose and there
# is something for refinement to win. Same system as the SOS example.
const SHEARED = PCC.StabilityProblem(
    PCC.switched_system([0.69 .* [0.0 1.0; -1.0 0.0], 0.69 .* [1.0 1.0; 0.0 1.0]]),
)

const MEMORYLESS = GraphAutomaton(1)
add_transition!(MEMORYLESS, 1, 1, 1)
add_transition!(MEMORYLESS, 1, 1, 2)

@testset "the node-grained lift cannot split the memoryless graph, and says so" begin
    # Two tight self-loops, so the tight-edge count selects node 1 -- but
    # `ForwardLift` splits by distinct *successor* and node 1 has only itself.
    # The lift is the identity here, and `refine` must report convergence rather
    # than re-solve the same graph until `depth_max`.
    trace = PCC.refine(
        TEMPLATE,
        MEMORYLESS,
        SHEARED;
        optimizer = OPTIMIZER,
        depth_max = 4,
        lift = PCC.ForwardLift(),
    )

    @test PCC.is_converged(trace)
    @test length(PCC.graphs(trace)) == 1
    @test PCC.n_nodes(only(PCC.graphs(trace))) == 1
end

@testset "the edge-grained lift refines it, and beats De Bruijn node for node" begin
    trace = PCC.refine(
        TEMPLATE,
        MEMORYLESS,
        SHEARED;
        optimizer = OPTIMIZER,
        depth_max = 4,
        lift = PCC.ForwardEdgeLift(),
    )

    rates = PCC.rates(trace)

    # Deterministic without a seed, which is the point: ties go to the cheapest
    # split, so this trajectory is the same on every Julia version. Seeding an
    # `rng` would NOT give that -- `rand(rng, ::Vector)` may sample differently
    # between versions, and this assertion failed on 1.10 while passing on 1.12.
    @test PCC.n_nodes.(PCC.graphs(trace)) == [1, 2, 3, 4]

    # The point of the whole loop: the bound genuinely falls, not merely fails to
    # rise. Anything weaker is satisfied by a lift that does nothing.
    @test all(<(0), diff(rates))

    # Two nodes reached by lifting is De Bruijn of order 1, up to relabeling, so
    # the bounds agree; four nodes reached by lifting is *not* De Bruijn of order
    # 2, and is strictly better than it.
    memory_1 = PCC.jsr_bound(TEMPLATE, PCC.de_bruijn(1, 2), SHEARED; optimizer = OPTIMIZER)
    memory_2 = PCC.jsr_bound(TEMPLATE, PCC.de_bruijn(2, 2), SHEARED; optimizer = OPTIMIZER)

    @test isapprox(rates[2], memory_1.rate; rtol = 1e-3)
    @test rates[4] < memory_2.rate

    # An explicit rng still breaks the remaining ties, and still refines.
    random = PCC.refine(
        TEMPLATE,
        MEMORYLESS,
        SHEARED;
        optimizer = OPTIMIZER,
        depth_max = 3,
        lift = PCC.ForwardEdgeLift(),
        rng = MersenneTwister(1),
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

@testset "an exact certificate stalls instead of growing the graph forever" begin
    # ROTATED and ROTATED2 are rotations scaled by 0.9, so P = I is an EXACT
    # certificate and the JSR is exactly 0.9 on any graph at all. Every edge is
    # therefore tight, every node always looks splittable, and NOTHING_TO_SPLIT
    # can never fire. Measured before this criterion existed: 2, 3, 5, 7, 10
    # nodes over five identical bounds, reporting no convergence.
    trace = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 5,
    )

    @test PCC.status(trace) == PCC.STALLED
    @test PCC.is_converged(trace)
    @test length(PCC.graphs(trace)) == 2
    @test all(rate -> isapprox(rate, 0.9; atol = 1e-3), PCC.rates(trace))

    # And the knob that lets a greedy search cross a plateau, at one bisection
    # per extra step.
    patient = PCC.refine(
        TEMPLATE,
        TWO_NODES,
        TWO_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        depth_max = 5,
        stall_max = 3,
    )

    @test PCC.status(patient) == PCC.STALLED
    @test length(PCC.graphs(patient)) == 4
end

@testset "the status tells the four outcomes apart" begin
    @test PCC.status(
        PCC.refine(
            TEMPLATE,
            ONE_NODE,
            ONE_MODE_PROBLEM;
            optimizer = OPTIMIZER,
            depth_max = 3,
        ),
    ) == PCC.NOTHING_TO_SPLIT

    @test PCC.status(
        PCC.refine(
            TEMPLATE,
            ONE_NODE,
            ONE_MODE_PROBLEM;
            optimizer = OPTIMIZER,
            depth_max = 3,
            until_stability = true,
        ),
    ) == PCC.STABLE

    @test PCC.status(
        PCC.refine(
            TEMPLATE,
            MEMORYLESS,
            SHEARED;
            optimizer = OPTIMIZER,
            depth_max = 2,
            lift = PCC.ForwardEdgeLift(),
        ),
    ) == PCC.DEPTH_EXHAUSTED
end

@testset "the two tolerances must be orders apart, and it is enforced" begin
    # At atol <= rtol the bisection residual alone makes every edge look tight,
    # so the test never discriminates -- a silent early stop, hence the throw.
    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        atol = 1e-6,
        rtol = 1e-6,
    )

    @test_throws ArgumentError PCC.refine(
        TEMPLATE,
        ONE_NODE,
        ONE_MODE_PROBLEM;
        optimizer = OPTIMIZER,
        stall_max = 0,
    )
end

@testset "path_complete decides the seed, and the lifts are trusted after it" begin
    settings = (optimizer = OPTIMIZER, depth_max = 3, lift = PCC.ForwardEdgeLift())

    # Waiving the check cannot change the answer on a graph that has the
    # property -- it only skips deciding it.
    checked = PCC.refine(TEMPLATE, MEMORYLESS, SHEARED; settings..., path_complete = true)
    waived = PCC.refine(TEMPLATE, MEMORYLESS, SHEARED; settings..., path_complete = false)

    @test PCC.rates(checked) == PCC.rates(waived)
    @test PCC.n_nodes.(PCC.graphs(checked)) == PCC.n_nodes.(PCC.graphs(waived))

    # Which is the half the loop relies on: preservation. Skipping the recheck is
    # only sound because every lift of a path-complete graph is path-complete,
    # and that is asserted here rather than at run time.
    @test all(graph -> PCC.is_path_complete(graph, 1:2), PCC.graphs(waived))

    # The seed, though, is still decided -- node 2 has no outgoing edge, so no
    # word ending in mode 2 is readable.
    dead_end = GraphAutomaton(2)
    add_transition!(dead_end, 1, 1, 1)
    add_transition!(dead_end, 1, 2, 2)

    @test !PCC.is_path_complete(dead_end, 1:2)
    @test_throws ArgumentError PCC.refine(TEMPLATE, dead_end, SHEARED; settings...)
end

end # module
