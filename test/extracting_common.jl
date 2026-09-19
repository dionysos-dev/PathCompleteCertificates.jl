module TestExtractingCommon

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import LinearAlgebra

const A = [[0.5 0.0; 0.0 0.25], [0.25 0.0; 0.0 0.5]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))
const X = [1.0, 2.0]

const P1 = LinearAlgebra.Symmetric([1.0 0.0; 0.0 1.0])
const P2 = LinearAlgebra.Symmetric([3.0 0.0; 0.0 3.0])
const PS = [P1, P2]

value(P) = LinearAlgebra.dot(X, P * X)

@testset "a complete graph aggregates with a minimum" begin
    graph = PCC.de_bruijn(1, 2)
    @test PCC.is_complete(graph)

    @test PCC.common(PCC.QuadraticTemplate, graph, PROBLEM, PS, X) ≈
          minimum(value(P) for P in PS)
end

@testset "a co-complete graph aggregates with a maximum" begin
    graph = PCC.de_bruijn(1, 2; orientation = :co_complete)
    @test PCC.is_co_complete(graph)

    @test PCC.common(PCC.QuadraticTemplate, graph, PROBLEM, PS, X) ≈
          maximum(value(P) for P in PS)
end

@testset "any other graph aggregates over the observer construction" begin
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

    expected = minimum(maximum(value(PS[node]) for node in state) for state in states)

    @test PCC.common(PCC.QuadraticTemplate, graph, PROBLEM, PS, X) ≈ expected
end

@testset "only the quadratic template is supported so far" begin
    @test_throws ArgumentError PCC.common(
        PCC.LinearCopositiveTemplate,
        PCC.de_bruijn(1, 2),
        PROBLEM,
        PS,
        X,
    )
end

end
