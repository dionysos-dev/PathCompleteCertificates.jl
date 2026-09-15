using Test
import PathCompleteCertificates as PCC

@testset "Graph" begin
    graph = PCC.Graph(3, [(1, 2, 1), (2, 3, 2), (3, 1, 1), (1, 3, 2)])

    @test PCC.n_nodes(graph) == 3
    @test PCC.n_edges(graph) == 4
    @test collect(PCC.nodes(graph)) == [1, 2, 3]

    @test PCC.source(graph.edges[1]) == 1
    @test PCC.target(graph.edges[1]) == 2
    @test PCC.label(graph.edges[1]) == 1

    @test length(PCC.outgoing_edges(graph, 1)) == 2
    @test length(PCC.incoming_edges(graph, 3)) == 2

    @test length(PCC.outgoing_edges(graph, 1, 1)) == 1
    @test length(PCC.outgoing_edges(graph, 1, 2)) == 1
    @test length(PCC.incoming_edges(graph, 3, 1)) == 0
    @test length(PCC.incoming_edges(graph, 3, 2)) == 2

    @test PCC.out_neighbors(graph, 1) == [2, 3]
    @test PCC.in_neighbors(graph, 1) == [3]

    @test PCC.labels(graph) == [1, 2]
    @test PCC.outgoing_labels(graph, 1) == [1, 2]
    @test PCC.incoming_labels(graph, 3) == [2]

    @test PCC.outdegree(graph, 1) == 2
    @test PCC.indegree(graph, 1) == 1
end

@testset "Graph completeness" begin
    G1 = PCC.Graph(3, [(1, 1, 1), (1, 2, 2), (2, 2, 1), (2, 3, 2), (3, 1, 1), (3, 3, 2)])

    @test PCC.is_complete(G1)
    @test !PCC.is_co_complete(G1)

    G2 = PCC.Graph(3, [(1, 2, 1), (2, 3, 2), (3, 1, 1)])

    @test !PCC.is_complete(G2)
    @test !PCC.is_co_complete(G2)

    G3 = PCC.Graph(3, [(1, 1, 1), (2, 1, 2), (2, 2, 1), (3, 2, 2), (3, 3, 1), (1, 3, 2)])

    @test PCC.is_complete(G3)
    @test PCC.is_co_complete(G3)
end

@testset "Graph validation" begin

    # Number of nodes
    @test_throws ArgumentError PCC.Graph(0, Tuple{Int, Int, Int}[])

    # Invalid source node
    @test_throws ArgumentError PCC.Graph(3, [(0, 1, 1),])

    # Invalid target node
    @test_throws ArgumentError PCC.Graph(3, [(1, 4, 1),])

    # Invalid node in graph queries
    graph = PCC.Graph(3, [(1, 2, 1),])

    @test_throws ArgumentError PCC.outgoing_edges(graph, 0)
    @test_throws ArgumentError PCC.outgoing_edges(graph, 4)

    @test_throws ArgumentError PCC.incoming_edges(graph, 0)
    @test_throws ArgumentError PCC.incoming_edges(graph, 4)
end
