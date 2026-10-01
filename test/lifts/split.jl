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
    lifted = PCC.ForwardEdgeSplit()(graph, out)
    g = PCC.graph(lifted)

    @test PCC.scope(PCC.ForwardEdgeSplit()) isa PCC.Local
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
    lifted = PCC.ForwardEdgeSplit()(graph, PCC.outgoing_edges(graph, 1))
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
    lifted = PCC.ForwardEdgeSplit()(graph, edge)
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
    split = PCC.graph(PCC.ForwardEdgeSplit()(loop, across))
    @test PCC.n_nodes(split) == 3
    @test PCC.outdegree(split, 3) == 1               # the copy owns (1, 2, 2)
    @test PCC.outdegree(split, 1) == 2               # the loop, to itself and to the copy
    @test PCC.is_path_complete(split, 1:2)
end

@testset "a self-loop in the locus returns from its copy to the node" begin
    # The one-node graph split at its mode-1 loop, as Athanasopoulos & Jungers
    # define it: the copy reads 1 back to the node, the node reads 1 into the
    # copy, and the node's other loop enters both.
    one = PCC.seed(OneStateAutomaton(2))
    loop = only(PCC.outgoing_edges(one, 1, 1))
    g = PCC.graph(PCC.ForwardEdgeSplit()(one, loop))

    @test PCC.n_nodes(g) == 2
    @test edgeset(g) == Set([(2, 1, [1]), (1, 2, [1]), (1, 1, [2]), (1, 2, [2])])
    @test PCC.is_path_complete(g, 1:2)

    # The dual, at the same loop: destinations split, edges reversed.
    d = PCC.graph(PCC.BackwardEdgeSplit()(one, loop))
    @test edgeset(d) == Set([(1, 2, [1]), (2, 1, [1]), (1, 1, [2]), (2, 1, [2])])
    @test PCC.is_path_complete(d, 1:2)
end

@testset "the backward split is the dual and splits destinations" begin
    graph = PCC.de_bruijn(1, 2)
    lifted = PCC.BackwardEdgeSplit()(graph, PCC.incoming_edges(graph, 1))
    g = PCC.graph(lifted)

    @test PCC.BackwardEdgeSplit() isa PCC.DualLift
    @test PCC.dual(PCC.BackwardEdgeSplit()) == PCC.ForwardEdgeSplit()
    @test PCC.n_nodes(g) == 3
    @test PCC.is_path_complete(g, 1:2)
    @test sort([PCC.indegree(g, n) for n in PCC.nodes(g)]) == [1, 2, 3]
    @test all(n -> PCC.outdegree(g, n) == 2, PCC.nodes(g))

    # Written out: the dual of the forward split on the dual graph.
    byhand = PCC.dual(
        PCC.graph(
            PCC.ForwardEdgeSplit()(PCC.dual(graph), PCC.outgoing_edges(PCC.dual(graph), 1)),
        ),
    )
    @test edgeset(byhand) == edgeset(g)
end

@testset "the memory lift from the one-node graph is De Bruijn" begin
    one = PCC.seed(OneStateAutomaton(2))

    for k in 1:3
        lifted = PCC.MemoryLift(k)(one)
        g = PCC.graph(lifted)
        db = PCC.de_bruijn(k, 2)

        @test PCC.n_nodes(g) == PCC.n_nodes(db)
        @test PCC.n_edges(g) == PCC.n_edges(db)
        @test PCC.is_complete(g, 1:2)
        @test PCC.is_path_complete(g, 1:2)
        @test all(==(1), PCC.origins(lifted))
        @test PCC.simulation(g, db) !== nothing && PCC.simulation(db, g) !== nothing
    end

    @test PCC.scope(PCC.MemoryLift(1)) isa PCC.Global
    @test_throws ArgumentError PCC.MemoryLift(0)
end

@testset "the memory lift of an automaton is the path-dependent lift" begin
    a = GraphAutomaton(2)
    add_transition!(a, 1, 1, 1)
    add_transition!(a, 1, 2, 2)
    add_transition!(a, 2, 1, 1)

    lifted = PCC.MemoryLift(1)(a)
    g = PCC.graph(lifted)

    # Nodes are the edges, edges the paths of length two.
    @test PCC.n_nodes(g) == PCC.n_edges(a)
    @test PCC.n_edges(g) == 5
    @test PCC.is_path_complete(g, a)
    @test PCC.origins(lifted) == [PCC.dest(e) for e in PCC.edges(a)]
end

@testset "lifts refuse a locus outside the graph or empty" begin
    graph = PCC.de_bruijn(1, 2)
    other = PCC.de_bruijn(2, 2)

    @test_throws ArgumentError PCC.ForwardEdgeSplit()(
        graph,
        HybridSystems.GraphTransition[],
    )
    @test_throws ArgumentError PCC.ForwardEdgeSplit()(graph, PCC.outgoing_edges(other, 3))
end

@testset "a split is valid for every template" begin
    system = PCC.switched_system([[0.5 0.0; 0.0 0.5], [0.0 0.5; 0.5 0.0]])

    @test PCC.requirements(PCC.ForwardEdgeSplit()) == ()
    @test PCC.requirements(PCC.BackwardEdgeSplit()) == ()

    for template in (
        PCC.QuadraticTemplate(),
        PCC.PolyhedralTemplate(1, 2),
        PCC.LinearCopositiveTemplate(),
    )
        @test PCC.is_valid(PCC.ForwardEdgeSplit(), template, system)
        @test PCC.is_valid(PCC.MemoryLift(2), template, system)
    end
end

@testset "a template with per-node data follows the split" begin
    graph = PCC.de_bruijn(1, 2)
    template = PCC.PolyhedralTemplate([[1.0 0.0; 0.0 1.0], [1.0 1.0; 0.0 1.0]])
    lifted = PCC.ForwardEdgeSplit()(graph, PCC.outgoing_edges(graph, 1))

    moved = PCC.reindex(template, PCC.origins(lifted))
    @test length(moved.G) == PCC.n_nodes(PCC.graph(lifted))
    @test moved.G == [template.G[o] for o in PCC.origins(lifted)]

    # A data-free template is its own reindexing.
    @test PCC.reindex(PCC.QuadraticTemplate(), PCC.origins(lifted)) ==
          PCC.QuadraticTemplate()
end

end # module
