using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "De Bruijn graphs" begin
    complete = PCC.de_bruijn(2, 2)
    @test PCC.n_nodes(complete) == 4
    @test PCC.n_edges(complete) == 8
    @test PCC.is_path_complete(complete)
    @test !PCC.is_co_path_complete(complete)

    for edge in PCC.edges(complete)
        @test PCC.label(complete, edge) in (1, 2)
        @test PCC.outdegree(complete, PCC.source(edge)) == 2
    end

    co_complete = PCC.de_bruijn(2, 2; orientation = :co_complete)
    @test PCC.n_nodes(co_complete) == 4
    @test PCC.n_edges(co_complete) == 8
    @test !PCC.is_path_complete(co_complete)
    @test PCC.is_co_path_complete(co_complete)

    @test_throws ArgumentError PCC.de_bruijn(0, 2)
    @test_throws ArgumentError PCC.de_bruijn(2, 0)
    @test_throws ArgumentError PCC.de_bruijn(2, 2; orientation = :invalid)
end

@testset "Observer graph" begin
    graph = GraphAutomaton(2)
    add_transition!(graph, 1, 1, 1)
    add_transition!(graph, 1, 2, 2)
    add_transition!(graph, 2, 1, 1)

    observer, states = PCC.observer_graph(graph)

    @test states == [Set([1, 2]), Set([1]), Set([2])]
    @test PCC.n_nodes(observer) == 3
    @test PCC.n_edges(observer) == 5
    @test [
        (PCC.source(edge), PCC.dest(edge), PCC.label(observer, edge)) for
        edge in PCC.edges(observer)
    ] == [(1, 2, 1), (1, 3, 2), (2, 2, 1), (2, 3, 2), (3, 2, 1)]

    # The missing label-2 transition from node 2 produces no empty observer state.
    @test all(!isempty(state) for state in states)
end
