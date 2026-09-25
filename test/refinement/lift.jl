using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "forward_lift splits a node into one copy per successor" begin
    graph = PCC.de_bruijn(2, 2)
    node = 1

    successors = unique(PCC.out_neighbors(graph, node))
    lifted = PCC.forward_lift(graph, node)

    @test PCC.n_nodes(lifted) == PCC.n_nodes(graph) - 1 + length(successors)
    @test sort(PCC.alphabet(lifted)) == sort(PCC.alphabet(graph))

    # The soundness property the whole algorithm rests on: lifting must not
    # lose path-completeness for the alphabet the graph carries.
    @test PCC.is_path_complete(lifted, PCC.alphabet(graph))

    # Edges away from `node` are untouched; edges into `node` (including a
    # self-loop) are duplicated onto every one of its `k` copies, and edges out
    # of `node` are kept one-for-one on their designated copy.
    e0, ein, eout, eself = 0, 0, 0, 0
    for edge in PCC.edges(graph)
        a, b = PCC.source(edge), PCC.dest(edge)
        if a != node && b != node
            e0 += 1
        elseif a == node && b == node
            eself += 1
        elseif a == node
            eout += 1
        else
            ein += 1
        end
    end
    k = length(successors)
    @test PCC.n_edges(lifted) == e0 + eout + k * (ein + eself)

    @test_throws ArgumentError PCC.forward_lift(GraphAutomaton(1), 1)
end

@testset "forward_edge_lift splits a node into one copy per outgoing edge" begin
    graph = PCC.de_bruijn(2, 2)
    node = 1

    out_edges = PCC.outgoing_edges(graph, node)
    lifted = PCC.forward_edge_lift(graph, node)

    @test PCC.n_nodes(lifted) == PCC.n_nodes(graph) - 1 + length(out_edges)
    @test PCC.is_path_complete(lifted, PCC.alphabet(graph))

    # Two edges to the same destination under different labels: forward_lift
    # collapses them onto one copy (no real split, since there is only one
    # distinct successor), forward_edge_lift keeps them apart.
    single = GraphAutomaton(1)
    add_transition!(single, 1, 1, 1)
    add_transition!(single, 1, 1, 2)

    node_lifted = PCC.forward_lift(single, 1)
    edge_lifted = PCC.forward_edge_lift(single, 1)

    @test PCC.n_nodes(node_lifted) == 1
    @test PCC.n_nodes(edge_lifted) == 2
    @test PCC.is_path_complete(edge_lifted, 1:2)

    # Up to relabeling, this is the dual (co-complete) De Bruijn graph of
    # order 1: every node has both labels incoming, neither has both outgoing.
    @test PCC.is_co_complete(edge_lifted)
    @test !PCC.is_complete(edge_lifted)
end

@testset "lifting requires an incident edge" begin
    isolated = GraphAutomaton(2)
    add_transition!(isolated, 1, 1, 1)

    @test_throws ArgumentError PCC.forward_lift(isolated, 2)
    @test_throws ArgumentError PCC.forward_edge_lift(isolated, 2)
end
