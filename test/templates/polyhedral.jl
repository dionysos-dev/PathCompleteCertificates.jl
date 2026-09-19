module TestPolyhedral

# The symmetric 2n-face polyhedral template of Athanasopoulos et al., ported
# from Dionysos `src/utils/pclf.jl` as an extensibility test of the two-axis
# design. It is the first template that is not determined by its type -- it
# carries one fixed matrix per node -- and the first whose functions are
# homogeneous of degree 1 rather than 2.

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
    template = PCC.PolyhedralTemplate(2, 2)

    @test length(template.G) == 2
    @test all(G == LinearAlgebra.I for G in template.G)
    @test template.min_weight > 0

    rotation = [0.0 -1.0; 1.0 0.0]
    rotated = PCC.PolyhedralTemplate([rotation, Matrix{Float64}(LinearAlgebra.I, 2, 2)])
    @test rotated.G[1] == rotation

    @test_throws ArgumentError PCC.PolyhedralTemplate(Matrix{Float64}[])
    @test_throws ArgumentError PCC.PolyhedralTemplate([zeros(2, 2)])          # singular
    @test_throws ArgumentError PCC.PolyhedralTemplate([ones(2, 3)])           # not square
    @test_throws ArgumentError PCC.PolyhedralTemplate(2, 2; min_weight = 0.0)
end

@testset "the node function is a weighted infinity norm" begin
    G = [2.0 0.0; 0.0 1.0]
    V = PCC.PolyhedralFunction(G, [1.0, 4.0])

    # max(|2*3|/1, |1*2|/4) = max(6, 0.5) = 6
    @test V([3.0, 2.0]) ≈ 6.0
    @test V([0.0, 0.0]) ≈ 0.0

    # Degree 1, unlike the quadratic template.
    @test V([6.0, 4.0]) ≈ 2 * V([3.0, 2.0])
end

@testset "synthesis recovers the rate" begin
    template = PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2)

    @test PCC.is_stable(template, GRAPH, PROBLEM, 0.6; optimizer = OPTIMIZER)
    @test !PCC.is_stable(template, GRAPH, PROBLEM, 0.4; optimizer = OPTIMIZER)

    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test result.feasible
    @test abs(result.bound - 0.5) <= 0.01
    @test length(result.V) == 2
end

@testset "the certificate satisfies the edge condition it claims" begin
    # Not the solver's status: check V_dst(A x) <= gamma * V_src(x) directly,
    # on the fitted weights, at sampled states.
    template = PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2)
    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    fitted = result.V

    for edge in PCC.edges(GRAPH)
        src = PCC.source(edge)
        dst = PCC.dest(edge)
        mode = PCC.label(GRAPH, edge)

        for x in ([1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [-2.0, 3.0], [0.7, -1.3])
            @test fitted[dst](A[mode] * x) <= result.bound * fitted[src](x) + 1e-6
        end
    end
end

@testset "a rotated template still certifies" begin
    # G is fixed data rather than a decision variable, so a different G is a
    # different -- and generally more conservative -- template on the same
    # graph. It must still produce a sound bound.
    theta = pi / 6
    rotation = [cos(theta) -sin(theta); sin(theta) cos(theta)]
    template = PCC.PolyhedralTemplate([copy(rotation), copy(rotation)])

    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test result.feasible
    @test result.bound >= 0.5 - 1e-6      # never below the true rate
    @test result.bound <= 1.0             # and still certifies contraction
end

@testset "the aggregation works for this template too" begin
    template = PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2)
    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    fitted = result.V

    x = [1.0, 2.0]
    value = PCC.common(template, GRAPH, PROBLEM, fitted, x)

    # GRAPH uses mode 1 only, and the system has one mode, so it is complete
    # and the aggregation is the minimum over nodes.
    @test PCC.is_complete(GRAPH, 1:1)
    @test value ≈ minimum(V(x) for V in fitted)
end

@testset "the template's weights are floored, not merely nonnegative" begin
    # `w` sits in a denominator. The LinearCopositive method would impose
    # `w >= 0` and leave V undefined; dispatching on the template is what stops
    # that, so check the floor is actually in force.
    template = PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2; min_weight = 2.5)
    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test result.feasible
    for V in result.V
        @test all(>=(2.5 - 1e-6), V.w)
    end
end

end
