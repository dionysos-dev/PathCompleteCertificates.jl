module TestGraphQueries

using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "the queries read the nodes, edges and labels" begin
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

    @test PCC.alphabet(graph) == [1, 2]

    @test PCC.outdegree(graph, 1) == 2
    @test PCC.indegree(graph, 1) == 1

    @test all(edge -> PCC.has_edge(graph, edge), PCC.edges(graph))
    other = PCC.empty_graph(3)
    @test !PCC.has_edge(graph, PCC.add_edge!(other, 2, 1, 1))
end

@testset "a query on a node that does not exist throws" begin
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)

    @test_throws ArgumentError PCC.outgoing_edges(graph, 0)
    @test_throws ArgumentError PCC.outgoing_edges(graph, 4)

    @test_throws ArgumentError PCC.incoming_edges(graph, 0)
    @test_throws ArgumentError PCC.incoming_edges(graph, 4)
end

@testset "the adjacency index agrees with the queries" begin
    g = PCC.de_bruijn(2, 2)
    index = PCC._successors(g)
    back = PCC._predecessors(g)

    for node in PCC.nodes(g), letter in 1:2
        @test sort(get(index, (node, letter), Int[])) ==
              sort([PCC.dest(e) for e in PCC.outgoing_edges(g, node, letter)])
        @test sort(get(back, (node, letter), Int[])) ==
              sort([PCC.source(e) for e in PCC.incoming_edges(g, node, letter)])
    end
end

end
