using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "ForwardEdgeLift splits a node into one copy per outgoing edge" begin
    graph = PCC.de_bruijn(2, 2)
    node = 1

    out_edges = PCC.outgoing_edges(graph, node)
    lifted = PCC.ForwardEdgeLift()(graph, node)

    @test PCC.n_nodes(lifted) == PCC.n_nodes(graph) - 1 + length(out_edges)
    @test sort(PCC.alphabet(lifted)) == sort(PCC.alphabet(graph))

    # The soundness property the whole algorithm rests on: lifting must not lose
    # path-completeness for the alphabet the graph carries.
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
    k = length(out_edges)
    @test PCC.n_edges(lifted) == e0 + eout + k * (ein + eself)
end

@testset "the edge grain separates what the successor grain could not" begin
    # Two self-loops under different labels. Splitting per successor would see
    # one successor and make one copy -- no split at all. Per edge it is two.
    single = GraphAutomaton(1)
    add_transition!(single, 1, 1, 1)
    add_transition!(single, 1, 1, 2)

    lifted = PCC.ForwardEdgeLift()(single, 1)

    @test PCC.n_nodes(lifted) == 2
    @test PCC.is_path_complete(lifted, 1:2)

    # Up to relabeling, this is the dual (co-complete) De Bruijn graph of order 1:
    # every node has both labels incoming, neither has both outgoing.
    @test PCC.is_co_complete(lifted)
    @test !PCC.is_complete(lifted)
end

@testset "lifting requires an outgoing edge" begin
    isolated = GraphAutomaton(2)
    add_transition!(isolated, 1, 1, 1)

    @test_throws ArgumentError PCC.ForwardEdgeLift()(isolated, 2)
    @test_throws ArgumentError PCC.ForwardEdgeLift()(GraphAutomaton(1), 1)
    @test_throws ArgumentError PCC.ForwardEdgeLift()(isolated, 3)
end

@testset "the copies are numbered last, in the order the edges are listed" begin
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 1, 3, 2)
    add_transition!(graph, 2, 3, 1)
    add_transition!(graph, 2, 1, 2)
    add_transition!(graph, 3, 1, 1)
    add_transition!(graph, 3, 2, 2)

    # Node 2 has two outgoing edges, so it becomes copies 3 and 4 while nodes 1
    # and 3 keep the low numbers.
    lifted = PCC.ForwardEdgeLift()(graph, 2)

    @test PCC.n_nodes(lifted) == 4
    @test PCC.is_path_complete(lifted, PCC.alphabet(graph))

    # Each copy keeps exactly one outgoing edge of the node it came from.
    @test PCC.outdegree(lifted, 3) == 1
    @test PCC.outdegree(lifted, 4) == 1
end
