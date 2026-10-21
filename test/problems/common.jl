module TestCommon

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import LinearAlgebra

const A = [[0.5 0.0; 0.0 0.25], [0.25 0.0; 0.0 0.5]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))
const X = [1.0, 2.0]

const P1 = PCC.QuadraticFunction(LinearAlgebra.Symmetric([1.0 0.0; 0.0 1.0]))
const P2 = PCC.QuadraticFunction(LinearAlgebra.Symmetric([3.0 0.0; 0.0 3.0]))
const VS = [P1, P2]

value(V) = V(X)

@testset "a complete graph combines with a minimum" begin
    graph = PCC.de_bruijn(1, 2)
    @test PCC.is_complete(graph)

    @test PCC.common(graph, PROBLEM, VS, X) ≈
          minimum(value(P) for P in VS)
end

@testset "a co-complete graph combines with a maximum" begin
    graph = PCC.dual(PCC.de_bruijn(1, 2))
    @test PCC.is_co_complete(graph)

    @test PCC.common(graph, PROBLEM, VS, X) ≈
          maximum(value(P) for P in VS)
end

@testset "any other graph combines over the observer construction" begin
    # Node 2 has no label-2 edge, so this graph is neither complete nor
    # co-complete and `common` must fall back to the observer construction --
    # a max within each observer state and a min across them.
    graph = GraphAutomaton(2)
    add_transition!(graph, 1, 1, 1)
    add_transition!(graph, 1, 2, 2)
    add_transition!(graph, 2, 1, 1)

    @test !PCC.is_complete(graph)
    @test !PCC.is_co_complete(graph)

    _, states = PCC.observer_graph(graph)
    @test states == [Set([1, 2]), Set([1]), Set([2])]

    expected = minimum(maximum(value(VS[node]) for node in state) for state in states)

    @test PCC.common(graph, PROBLEM, VS, X) ≈ expected
end

@testset "the common function is generic in the template" begin
    graph = PCC.de_bruijn(1, 2)
    linear = PCC.LinearCopositiveFunction.([[1.0, 1.0], [2.0, 2.0]])

    @test PCC.common(graph, PROBLEM, linear, X) ≈ minimum(
        PCC.node_value(PROBLEM, V, X) for V in linear
    )

    weights = [
        PCC.ParallelFacesPolyhedralFunction(
            Matrix{Float64}(LinearAlgebra.I, 2, 2),
            [1.0, 1.0],
        ),
        PCC.ParallelFacesPolyhedralFunction(
            Matrix{Float64}(LinearAlgebra.I, 2, 2),
            [4.0, 4.0],
        ),
    ]

    @test PCC.common(graph,
        PROBLEM,
        weights,
        X,
    ) ≈ minimum(
        PCC.node_value(PROBLEM, V, X) for
        V in weights
    )
end

end
