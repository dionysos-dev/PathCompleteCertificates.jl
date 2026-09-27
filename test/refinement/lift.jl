using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "ForwardLift splits a node into one copy per successor" begin
    graph = PCC.de_bruijn(2, 2)
    node = 1

    successors = unique(PCC.out_neighbors(graph, node))
    lifted = PCC.ForwardLift()(graph, node)

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

    @test_throws ArgumentError PCC.ForwardLift()(GraphAutomaton(1), 1)
end

@testset "ForwardEdgeLift splits a node into one copy per outgoing edge" begin
    graph = PCC.de_bruijn(2, 2)
    node = 1

    out_edges = PCC.outgoing_edges(graph, node)
    lifted = PCC.ForwardEdgeLift()(graph, node)

    @test PCC.n_nodes(lifted) == PCC.n_nodes(graph) - 1 + length(out_edges)
    @test PCC.is_path_complete(lifted, PCC.alphabet(graph))

    # Two edges to the same destination under different labels: ForwardLift
    # collapses them onto one copy (no real split, since there is only one
    # distinct successor), ForwardEdgeLift keeps them apart.
    single = GraphAutomaton(1)
    add_transition!(single, 1, 1, 1)
    add_transition!(single, 1, 1, 2)

    node_lifted = PCC.ForwardLift()(single, 1)
    edge_lifted = PCC.ForwardEdgeLift()(single, 1)

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

    @test_throws ArgumentError PCC.ForwardLift()(isolated, 2)
    @test_throws ArgumentError PCC.ForwardEdgeLift()(isolated, 2)
end

@testset "copies says what a lift would separate, and builds no graph to do it" begin
    single = GraphAutomaton(1)
    add_transition!(single, 1, 1, 1)
    add_transition!(single, 1, 1, 2)

    # The grain, stated as a count: one successor, two edges.
    @test length(PCC.copies(PCC.ForwardLift(), single, 1)) == 1
    @test length(PCC.copies(PCC.ForwardEdgeLift(), single, 1)) == 2

    graph = PCC.de_bruijn(2, 2)

    for lift in (PCC.ForwardLift(), PCC.ForwardEdgeLift())
        groups = PCC.copies(lift, graph, 1)

        # The two agree by construction: the lift makes one node per copy, and
        # every outgoing edge lands in exactly one of them.
        @test PCC.n_nodes(lift(graph, 1)) == PCC.n_nodes(graph) - 1 + length(groups)
        @test sum(length, groups) == PCC.outdegree(graph, 1)
    end

    # A query answers, the transform refuses -- so a caller can ask whether a
    # split is available without guarding against an exception.
    isolated = GraphAutomaton(2)
    add_transition!(isolated, 1, 1, 1)

    @test isempty(PCC.copies(PCC.ForwardLift(), isolated, 2))
    @test_throws ArgumentError PCC.copies(PCC.ForwardLift(), isolated, 3)
end
