module TestParallelFacesPolyhedral

# The parallel-faces polyhedral template: one fixed matrix per node, functions
# homogeneous of degree 1.

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra
using LinearAlgebra: normalize

const OPTIMIZER = Clarabel.Optimizer

# rho(A) = 0.5, and the identity template certifies it exactly: the weighted
# infinity norm with w = (1, 1) is already a Lyapunov function here.
const A = [[0.5 0.0; 0.0 0.25]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)

const GRAPH = GraphAutomaton(2)
add_transition!(GRAPH, 1, 2, 1)
add_transition!(GRAPH, 2, 1, 1)

@testset "the template carries per-node data" begin
    template = PCC.ParallelFacesPolyhedralTemplate(2, 2)

    @test length(template.G) == 2
    @test all(G == LinearAlgebra.I for G in template.G)
    @test template.min_weight > 0

    rotation = [0.0 -1.0; 1.0 0.0]
    rotated = PCC.ParallelFacesPolyhedralTemplate([
        rotation,
        Matrix{Float64}(LinearAlgebra.I, 2, 2),
    ])
    @test rotated.G[1] == rotation

    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(Matrix{Float64}[])
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate([zeros(2, 2)])          # singular
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate([ones(2, 3)])           # not square
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(2, 2; min_weight = 0.0)

    # Integer face normals take the default floor in floating point.
    integer = PCC.ParallelFacesPolyhedralTemplate([[1 0; 0 1]])
    @test integer.min_weight > 0
    @test only(integer.G) == LinearAlgebra.I
end

@testset "the node function is a weighted infinity norm" begin
    G = [2.0 0.0; 0.0 1.0]
    V = PCC.ParallelFacesPolyhedralFunction(G, [1.0, 4.0])

    # max(|2*3|/1, |1*2|/4) = max(6, 0.5) = 6
    @test V([3.0, 2.0]) ≈ 6.0
    @test V([0.0, 0.0]) ≈ 0.0

    # Degree 1, unlike the quadratic template.
    @test V([6.0, 4.0]) ≈ 2 * V([3.0, 2.0])
end

@testset "synthesis recovers the rate" begin
    template = PCC.ParallelFacesPolyhedralTemplate(PCC.n_nodes(GRAPH), 2)

    @test PCC.is_feasible(
        PCC.certify(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rate = 0.6),
    )
    @test !PCC.is_feasible(
        PCC.certify(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rate = 0.4),
    )

    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test PCC.is_feasible(result)
    @test abs(result.rate - 0.5) <= 0.01
    @test length(PCC.functions(result)) == 2
end

@testset "the certificate satisfies the edge condition it claims" begin
    # Not the solver's status: check V_dst(A x) <= gamma * V_src(x) directly,
    # on the fitted weights, at sampled states.
    template = PCC.ParallelFacesPolyhedralTemplate(PCC.n_nodes(GRAPH), 2)
    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    fitted = PCC.functions(result)

    for edge in PCC.edges(GRAPH)
        src = PCC.source(edge)
        dst = PCC.dest(edge)
        mode = PCC.label(GRAPH, edge)

        for x in ([1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [-2.0, 3.0], [0.7, -1.3])
            @test fitted[dst](A[mode] * x) <= result.rate * fitted[src](x) + 1e-6
        end
    end
end

@testset "a rotated template still certifies" begin
    # G is fixed data rather than a decision variable, so a different G is a
    # different -- and generally more conservative -- template on the same
    # graph. It must still produce a sound bound.
    theta = pi / 6
    rotation = [cos(theta) -sin(theta); sin(theta) cos(theta)]
    template = PCC.ParallelFacesPolyhedralTemplate([copy(rotation), copy(rotation)])

    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test PCC.is_feasible(result)
    @test result.rate >= 0.5 - 1e-6      # never below the true rate
    @test result.rate <= 1.0             # and still certifies contraction
end

@testset "the common function works for this template too" begin
    template = PCC.ParallelFacesPolyhedralTemplate(PCC.n_nodes(GRAPH), 2)
    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    fitted = PCC.functions(result)

    x = [1.0, 2.0]
    value = PCC.common(template, GRAPH, PROBLEM, fitted, x)

    # GRAPH uses mode 1 only, and the system has one mode, so it is complete
    # and the common function is the minimum over nodes.
    @test PCC.is_complete(GRAPH, 1:1)
    @test value ≈ minimum(V(x) for V in fitted)
end

@testset "the template's weights are floored, not merely nonnegative" begin
    # `w` sits in a denominator. The LinearCopositive method would impose
    # `w >= 0` and leave V undefined; dispatching on the template is what stops
    # that, so check the floor is actually in force.
    template = PCC.ParallelFacesPolyhedralTemplate(PCC.n_nodes(GRAPH), 2; min_weight = 2.5)
    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test PCC.is_feasible(result)
    for V in PCC.functions(result)
        @test all(>=(2.5 - 1e-6), V.w)
    end
end

end
