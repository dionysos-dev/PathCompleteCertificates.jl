module TestLiftSplit

using Test
using HybridSystems
import PathCompleteCertificates as PCC

edgeset(g) = Set(
    (PCC.source(e), PCC.dest(e), collect(PCC.letters(PCC.label(g, e)))) for
    e in PCC.edges(g)
)

@testset "splitting a node along its out-star: one copy per outgoing edge" begin
    graph = PCC.de_bruijn(2, 2)
    node = 1

    out = PCC.outgoing_edges(graph, node)
    lifted = PCC.lift(PCC.OutSplitLift(), graph, out)
    g = PCC.graph(lifted)

    @test PCC.n_nodes(g) == PCC.n_nodes(graph) - 1 + length(out)
    @test sort(PCC.alphabet(g)) == sort(PCC.alphabet(graph))
    @test PCC.is_path_complete(g, PCC.alphabet(graph))

    # Copies are numbered last and come from the split node.
    @test PCC.origins(lifted)[(end - length(out) + 1):end] == fill(node, length(out))
    @test PCC.origins(lifted)[1:(end - length(out))] ==
          [n for n in PCC.nodes(graph) if n != node]

    # Edges away from `node` untouched; edges into `node` duplicated onto every
    # copy; edges out of `node` kept one-for-one on their copy.
    e0 = count(e -> PCC.source(e) != node && PCC.dest(e) != node, PCC.edges(graph))
    ein = count(e -> PCC.source(e) != node && PCC.dest(e) == node, PCC.edges(graph))
    eself = count(e -> PCC.source(e) == node && PCC.dest(e) == node, PCC.edges(graph))
    eout = count(e -> PCC.source(e) == node && PCC.dest(e) != node, PCC.edges(graph))
    k = length(out)
    @test PCC.n_edges(g) == e0 + eout + k * (ein + eself)

    # Each copy owns one outgoing edge; a copy owning a self-loop leaves towards
    # every copy, so it has k, and the others one.
    copies = (PCC.n_nodes(g) - k + 1):PCC.n_nodes(g)
    @test sort([PCC.outdegree(g, c) for c in copies]) == sort([fill(1, eout); fill(k, eself)])
end

@testset "a self-loop enters every copy and leaves the one that owns it" begin
    graph = PCC.de_bruijn(1, 2)
    lifted = PCC.lift(PCC.OutSplitLift(), graph, PCC.outgoing_edges(graph, 1))
    g = PCC.graph(lifted)

    @test PCC.n_nodes(g) == 3
    @test PCC.n_edges(g) == 6
    @test sort([PCC.outdegree(g, n) for n in PCC.nodes(g)]) == [1, 2, 3]
    @test all(n -> PCC.indegree(g, n) == 2, PCC.nodes(g))
    @test PCC.is_path_complete(g, 1:2)
end

@testset "a partial split leaves the node with its other edges" begin
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 1, 3, 2)
    add_transition!(graph, 2, 3, 1)
    add_transition!(graph, 2, 1, 2)
    add_transition!(graph, 3, 1, 1)
    add_transition!(graph, 3, 2, 2)

    edge = only(PCC.outgoing_edges(graph, 2, 1))     # (2, 3, 1)
    lifted = PCC.lift(PCC.OutSplitLift(), graph, edge)
    g = PCC.graph(lifted)

    # Node 2 survives with its other edge; the copy, numbered last, owns this
    # one; both receive every edge into 2.
    @test PCC.n_nodes(g) == 4
    @test PCC.origins(lifted) == [1, 2, 3, 2]
    @test PCC.outdegree(g, 2) == 1
    @test PCC.outdegree(g, 4) == 1
    @test PCC.indegree(g, 2) == 2
    @test PCC.indegree(g, 4) == 2
    @test PCC.n_edges(g) == 8
    @test PCC.is_path_complete(g, 1:2)

    # On a node with a self-loop the loop enters every image of the node, the
    # surviving original included, so the degrees grow accordingly.
    loop = PCC.de_bruijn(1, 2)
    across = only(PCC.outgoing_edges(loop, 1, 2))   # (1, 2, 2)
    split = PCC.graph(PCC.lift(PCC.OutSplitLift(), loop, across))
    @test PCC.n_nodes(split) == 3
    @test PCC.outdegree(split, 3) == 1               # the copy owns (1, 2, 2)
    @test PCC.outdegree(split, 1) == 2               # the loop, to itself and to the copy
    @test PCC.is_path_complete(split, 1:2)
end

@testset "a given self-loop returns from its copy to the node" begin
    # The one-node graph split at its mode-1 loop, as Athanasopoulos & Jungers
    # define it: the copy reads 1 back to the node, the node reads 1 into the
    # copy, and the node's other loop enters both.
    one = PCC.common_graph(2)
    loop = only(PCC.outgoing_edges(one, 1, 1))
    g = PCC.graph(PCC.lift(PCC.OutSplitLift(), one, loop))

    @test PCC.n_nodes(g) == 2
    @test edgeset(g) == Set([(2, 1, [1]), (1, 2, [1]), (1, 1, [2]), (1, 2, [2])])
    @test PCC.is_path_complete(g, 1:2)

    # The dual, at the same loop: destinations split, edges reversed.
    d = PCC.graph(PCC.lift(PCC.InSplitLift(), one, loop))
    @test edgeset(d) == Set([(1, 2, [1]), (2, 1, [1]), (1, 1, [2]), (2, 1, [2])])
    @test PCC.is_path_complete(d, 1:2)
end

@testset "the in-splitting is the dual and splits destinations" begin
    graph = PCC.de_bruijn(1, 2)
    lifted = PCC.lift(PCC.InSplitLift(), graph, PCC.incoming_edges(graph, 1))
    g = PCC.graph(lifted)

    @test PCC.InSplitLift() isa PCC.DualLift
    @test PCC.dual(PCC.InSplitLift()) == PCC.OutSplitLift()
    @test PCC.n_nodes(g) == 3
    @test PCC.is_path_complete(g, 1:2)
    @test sort([PCC.indegree(g, n) for n in PCC.nodes(g)]) == [1, 2, 3]
    @test all(n -> PCC.outdegree(g, n) == 2, PCC.nodes(g))

    # Written out: the dual of the out-splitting on the dual graph.
    byhand = PCC.dual(
        PCC.graph(
            PCC.lift(
                PCC.OutSplitLift(),
                PCC.dual(graph),
                PCC.outgoing_edges(PCC.dual(graph), 1),
            ),
        ),
    )
    @test edgeset(byhand) == edgeset(g)
end

@testset "the path-dependent lift from the one-node graph is De Bruijn" begin
    one = PCC.common_graph(2)

    for k in 1:3
        lifted = PCC.lift(PCC.PathDependentLift(k), one)
        g = PCC.graph(lifted)
        db = PCC.de_bruijn(k, 2)

        @test PCC.n_nodes(g) == PCC.n_nodes(db)
        @test PCC.n_edges(g) == PCC.n_edges(db)
        @test PCC.is_complete(g, 1:2)
        @test PCC.is_path_complete(g, 1:2)
        @test all(==(1), PCC.origins(lifted))
        @test PCC.simulation(g, db) !== nothing && PCC.simulation(db, g) !== nothing
    end

    @test_throws ArgumentError PCC.PathDependentLift(0)
end

@testset "the dual of the path-dependent lift is the dual De Bruijn hierarchy" begin
    one = PCC.common_graph(2)

    for k in 1:2
        lifted = PCC.lift(PCC.dual(PCC.PathDependentLift(k)), one)
        g = PCC.graph(lifted)
        db = PCC.dual(PCC.de_bruijn(k, 2))

        @test PCC.n_nodes(g) == PCC.n_nodes(db)
        @test PCC.n_edges(g) == PCC.n_edges(db)
        @test PCC.is_co_complete(g, 1:2)
        @test PCC.simulation(g, db) !== nothing && PCC.simulation(db, g) !== nothing
    end

    @test PCC.dual(PCC.dual(PCC.PathDependentLift(1))) == PCC.PathDependentLift(1)
end

@testset "the path-dependent lift: its nodes are the edges" begin
    a = GraphAutomaton(2)
    add_transition!(a, 1, 1, 1)
    add_transition!(a, 1, 2, 2)
    add_transition!(a, 2, 1, 1)

    lifted = PCC.lift(PCC.PathDependentLift(1), a)
    g = PCC.graph(lifted)

    # Nodes are the edges, edges the paths of length two.
    @test PCC.n_nodes(g) == PCC.n_edges(a)
    @test PCC.n_edges(g) == 5

    # Both read the same words: here, every word without `2, 2`.
    function reads(graph, word)
        ends = Set(PCC.nodes(graph))
        for mode in word
            ends =
                Set(PCC.dest(e) for n in ends for e in PCC.outgoing_edges(graph, n, mode))
        end
        return !isempty(ends)
    end
    for k in 1:5, word in Iterators.product(ntuple(_ -> 1:2, k)...)
        @test reads(g, word) == reads(a, word)
    end
    @test PCC.origins(lifted) == [PCC.dest(e) for e in PCC.edges(a)]
end

@testset "at a node, the out-splitting of Ninite & Jungers: one copy per outgoing edge" begin
    # Node 1 reads 1 and 2 into node 2 and 1 into itself: three outgoing edges,
    # two of them to the same successor.
    g = GraphAutomaton(2)
    for (a, b, l) in ((1, 2, 1), (1, 2, 2), (1, 1, 1), (2, 1, 1), (2, 2, 2))
        add_transition!(g, a, b, l)
    end

    lifted = PCC.lift(PCC.OutSplitLift(), g, 1)
    h = PCC.graph(lifted)

    # Node 2 survives as 1; node 1 is replaced by its three copies.
    @test PCC.origins(lifted) == [2, 1, 1, 1]
    @test PCC.is_path_complete(h, 1:2)

    # The lift at a node is the lift at all its outgoing edges.
    @test edgeset(h) ==
          edgeset(PCC.graph(PCC.lift(PCC.OutSplitLift(), g, PCC.outgoing_edges(g, 1))))

    # On the one-node graph, one copy per loop: the dual De Bruijn graph, each
    # copy leaving by its own mode for every copy.
    one = PCC.common_graph(2)
    split = PCC.graph(PCC.lift(PCC.OutSplitLift(), one, 1))
    @test PCC.n_nodes(split) == 2
    @test PCC.n_edges(split) == 4
    for node in PCC.nodes(split)
        out = PCC.outgoing_edges(split, node)
        @test length(unique(PCC.label(split, e) for e in out)) == 1
        @test sort(PCC.dest.(out)) == [1, 2]
    end

    # The in-splitting is the dual: one copy per incoming edge.
    back = PCC.lift(PCC.InSplitLift(), g, 1)
    @test edgeset(PCC.graph(back)) ==
          edgeset(PCC.dual(PCC.graph(PCC.lift(PCC.OutSplitLift(), PCC.dual(g), 1))))

    @test_throws ArgumentError PCC.lift(PCC.OutSplitLift(), g, 3)
    @test_throws MethodError PCC.lift(PCC.MinLift(), g, 1)
end

@testset "a split keeps the nodes it does not touch, sinks and sources included" begin
    # Node 3 has no outgoing edge and node 4 no incoming one.
    g = PCC.empty_graph(4)
    for (s, d, mode) in [
        (1, 1, 1),
        (1, 2, 2),
        (2, 1, 1),
        (2, 2, 2),
        (1, 3, 1),
        (2, 3, 2),
        (4, 1, 1),
        (4, 2, 2),
    ]
        PCC.add_edge!(g, s, d, mode)
    end
    loop = only(e for e in PCC.edges(g) if PCC.source(e) == PCC.dest(e) == 1)

    # At an edge, one copy of node 1 is added and no node is lost.
    for L in (PCC.OutSplitLift(), PCC.InSplitLift())
        lifted = PCC.lift(L, g, [loop])
        @test PCC.n_nodes(PCC.graph(lifted)) == 5
        @test sort(unique(PCC.origins(lifted))) == 1:4
    end

    # At a node, the out-splitting of Ninite & Jungers keeps every other node.
    @test sort(unique(PCC.origins(PCC.lift(PCC.OutSplitLift(), g, 1)))) == 1:4
end

@testset "lifts refuse edges outside the graph or none" begin
    graph = PCC.de_bruijn(1, 2)
    other = PCC.de_bruijn(2, 2)

    @test_throws ArgumentError PCC.lift(
        PCC.OutSplitLift(),
        graph,
        HybridSystems.GraphTransition[],
    )
    @test_throws ArgumentError PCC.lift(
        PCC.OutSplitLift(),
        graph,
        PCC.outgoing_edges(other, 3),
    )

    # Listing an edge twice would make two copies own it, one of them with no
    # outgoing edge.
    twice = PCC.outgoing_edges(graph, 1)[1:1]
    @test_throws ArgumentError PCC.lift(PCC.OutSplitLift(), graph, [twice; twice])
end

@testset "origins is a homomorphism into the original: valid for every template" begin
    # Debauche, Della Rossa & Jungers, Def. 6(c): a lift is valid for
    # every template when the original simulates the lifted graph, and the
    # origins are that map.
    loops = GraphAutomaton(3)
    for (a, b, l) in
        ((1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2), (2, 3, 1), (3, 1, 2), (3, 3, 2))
        add_transition!(loops, a, b, l)
    end

    preserved(lifted, g) = all(
        e -> (
            PCC.origins(lifted)[PCC.source(e)],
            PCC.origins(lifted)[PCC.dest(e)],
            collect(PCC.letters(PCC.label(PCC.graph(lifted), e))),
        ) in edgeset(g),
        PCC.edges(PCC.graph(lifted)),
    )

    for g in (PCC.de_bruijn(2, 2), loops, PCC.common_graph(2))
        edge_lists = [[e] for e in PCC.edges(g)]
        push!(edge_lists, collect(PCC.edges(g)))

        for L in (PCC.OutSplitLift(), PCC.InSplitLift()), edge_list in edge_lists
            lifted = PCC.lift(L, g, edge_list)
            @test PCC.is_path_complete(PCC.graph(lifted), 1:2)
            @test preserved(lifted, g)
        end

        @test preserved(PCC.lift(PCC.PathDependentLift(2), g), g)
    end
end

@testset "a template with per-node data follows the split" begin
    graph = PCC.de_bruijn(1, 2)
    template = PCC.ParallelFacesPolyhedralTemplate([[1.0 0.0; 0.0 1.0], [1.0 1.0; 0.0 1.0]])
    lifted = PCC.lift(PCC.OutSplitLift(), graph, PCC.outgoing_edges(graph, 1))

    moved = PCC.reindex(template, PCC.origins(lifted))
    @test length(moved) == PCC.n_nodes(PCC.graph(lifted))
    @test moved == [template[o] for o in PCC.origins(lifted)]

    # A data-free template is its own reindexing.
    @test PCC.reindex(PCC.QuadraticTemplate(), PCC.origins(lifted)) ==
          PCC.QuadraticTemplate()
end

end # module
