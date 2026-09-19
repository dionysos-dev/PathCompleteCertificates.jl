using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "Graph" begin
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 2, 3, 2)
    add_transition!(graph, 3, 1, 1)
    add_transition!(graph, 1, 3, 2)

    @test PCC.n_nodes(graph) == 3
    @test PCC.n_edges(graph) == 4
    @test collect(PCC.nodes(graph)) == [1, 2, 3]

    transition = first(PCC.edges(graph))
    @test PCC.source(transition) == 1
    @test PCC.dest(transition) == 2
    @test PCC.label(graph, transition) == 1

    @test length(PCC.outgoing_edges(graph, 1)) == 2
    @test length(PCC.incoming_edges(graph, 3)) == 2

    @test length(PCC.outgoing_edges(graph, 1, 1)) == 1
    @test length(PCC.outgoing_edges(graph, 1, 2)) == 1
    @test length(PCC.incoming_edges(graph, 3, 1)) == 0
    @test length(PCC.incoming_edges(graph, 3, 2)) == 2

    @test PCC.out_neighbors(graph, 1) == [2, 3]
    @test PCC.in_neighbors(graph, 1) == [3]

    @test PCC.alphabet(graph) == [1, 2]
    @test PCC.outgoing_alphabet(graph, 1) == [1, 2]
    @test PCC.incoming_alphabet(graph, 3) == [2]

    @test PCC.outdegree(graph, 1) == 2
    @test PCC.indegree(graph, 1) == 1
end

@testset "Graph validation" begin

    # Number of nodes
    # Invalid node in graph queries
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)

    @test_throws ArgumentError PCC.outgoing_edges(graph, 0)
    @test_throws ArgumentError PCC.outgoing_edges(graph, 4)

    @test_throws ArgumentError PCC.incoming_edges(graph, 0)
    @test_throws ArgumentError PCC.incoming_edges(graph, 4)
end
