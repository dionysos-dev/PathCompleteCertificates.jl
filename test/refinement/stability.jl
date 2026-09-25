module TestRefinementStability

using Test
using HybridSystems
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

end # module
