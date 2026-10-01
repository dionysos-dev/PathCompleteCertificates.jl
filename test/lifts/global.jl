module TestLiftGlobal

using Test
using HybridSystems
import PathCompleteCertificates as PCC

edgeset(g) = Set((PCC.source(e), PCC.dest(e), PCC.label(g, e)) for e in PCC.edges(g))

function graph(edges, n)
    g = GraphAutomaton(n)
    for (a, b, l) in edges
        add_transition!(g, a, b, l)
    end
    return g
end

# Jongeneel & Jungers, Fig. 1: G1 and G2 are the backward and forward
# 1-composition lifts of the one-node graph (their Example III.2).
const JJ_G1 = graph([(1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2)], 2)   # de Bruijn order 1 up to naming
const JJ_G2 = graph([(1, 1, 1), (1, 2, 1), (2, 2, 2), (2, 1, 2)], 2)

@testset "the composition lift of the one-node graph, forward and backward" begin
    one = PCC.seed(OneStateAutomaton(2))

    forward = PCC.CompositionLift(1)(one)
    g = PCC.graph(forward)
    @test PCC.n_nodes(g) == 2
    @test PCC.origins(forward) == [(1, [1]), (1, [2])]
    # Node (1, j) reads j and goes to (1, i) for every edge (1,1,i): that is G2.
    @test edgeset(g) == edgeset(JJ_G2)
    @test PCC.is_path_complete(g, 1:2)

    backward = PCC.dual(PCC.CompositionLift(1))(one)
    @test edgeset(PCC.graph(backward)) == edgeset(JJ_G1)

    @test PCC.scope(PCC.CompositionLift(1)) isa PCC.Global
    @test PCC.requirements(PCC.CompositionLift(2)) == (PCC.Composition(),)
    @test PCC.requirements(PCC.dual(PCC.CompositionLift(2))) == (PCC.InverseComposition(),)
    @test_throws ArgumentError PCC.CompositionLift(0)
end

@testset "the composition lift needs invertible dynamics, read from the system" begin
    invertible = PCC.switched_system([[0.5 0.0; 0.0 0.5], [0.0 0.5; 0.5 0.0]])
    singular = PCC.switched_system([[0.5 0.0; 0.0 0.0], [0.0 0.5; 0.5 0.0]])

    @test PCC.is_invertible(invertible)
    @test !PCC.is_invertible(singular)
    @test PCC.is_valid(PCC.CompositionLift(1), PCC.QuadraticTemplate(), invertible)
    @test !PCC.is_valid(PCC.CompositionLift(1), PCC.QuadraticTemplate(), singular)
    @test PCC.is_valid(
        PCC.dual(PCC.CompositionLift(1)),
        PCC.QuadraticTemplate(),
        invertible,
    )
    @test !PCC.is_valid(PCC.CompositionLift(1), PCC.PolyhedralTemplate(1, 2), invertible)
end

@testset "the composition lift of a larger graph has |S|·M^T nodes" begin
    g = PCC.de_bruijn(1, 2)
    lifted = PCC.CompositionLift(2)(g)
    @test PCC.n_nodes(PCC.graph(lifted)) == 2 * 4
    @test PCC.n_edges(PCC.graph(lifted)) == PCC.n_edges(g) * 4
    @test PCC.is_path_complete(PCC.graph(lifted), 1:2)
end

@testset "the min lift, the max lift as its dual, and their subsets" begin
    g = PCC.de_bruijn(1, 2)
    lifted = PCC.MinLift()(g)
    m = PCC.graph(lifted)

    @test PCC.n_nodes(m) == 3
    @test PCC.origins(lifted) == [[1], [2], [1, 2]]
    @test PCC.is_path_complete(m, 1:2)
    @test PCC.requirements(PCC.MinLift()) == (PCC.Minimum(),)
    @test PCC.requirements(PCC.MaxLift()) == (PCC.Maximum(),)

    # The singletons carry a copy of the graph.
    singleton = Set(t for t in edgeset(m) if t[1] <= 2 && t[2] <= 2)
    @test singleton == edgeset(g)

    # De Bruijn is complete, so the full subset has both loops (Prop. 3a).
    @test (3, 3, 1) in edgeset(m) && (3, 3, 2) in edgeset(m)

    # Max lift written out against the definition: ∀ b ∈ B ∃ a ∈ A (a, b, i).
    x = PCC.graph(PCC.MaxLift()(g))
    index = PCC.successors(g)
    subsets = PCC.origins(lifted)
    for (a, A) in enumerate(subsets), (b, B) in enumerate(subsets), i in 1:2
        expected = all(bb -> any(bb in get(index, (aa, i), Int[]) for aa in A), B)
        @test ((a, b, i) in edgeset(x)) == expected
    end

    @test_throws ArgumentError PCC.MinLift()(PCC.de_bruijn(4, 2))
end

@testset "the sum lift by perfect matching" begin
    g = PCC.de_bruijn(1, 2)
    lifted = PCC.SumLift(2)(g)
    s = PCC.graph(lifted)

    @test PCC.origins(lifted) == [[1, 1], [1, 2], [2, 2]]
    @test PCC.is_path_complete(s, 1:2)
    @test PCC.requirements(PCC.SumLift(2)) == (PCC.Addition(),)

    # {1,1} → {1,1} under 1 uses the loop (1,1,1) twice: a multiset of edges may
    # repeat one, which is what makes {a,…,a} a copy of the graph (Prop. 7.10).
    @test (1, 1, 1) in edgeset(s)
    # {1,2} → {1,2} under 1: (1,1,1) and (2,1,1) both land on 1, no matching.
    @test !((2, 2, 1) in edgeset(s))
    # {1,1} → {2,2} under 2: (1,2,2) twice.
    @test (1, 3, 2) in edgeset(s)

    # Self-dual (Debauche, Prop. 7.13).
    @test edgeset(PCC.dual(s)) == edgeset(PCC.graph(PCC.SumLift(2)(PCC.dual(g))))
    @test_throws ArgumentError PCC.SumLift(0)

    # The guard is on the lifted graph: eight nodes have 6435 multisets of eight.
    @test_throws ArgumentError PCC.SumLift(8)(PCC.de_bruijn(3, 2))
end

@testset "every global lift preserves path-completeness" begin
    for g in (PCC.de_bruijn(1, 2), PCC.de_bruijn(2, 2), JJ_G1, JJ_G2),
        lift in (
            PCC.CompositionLift(1),
            PCC.dual(PCC.CompositionLift(1)),
            PCC.MinLift(),
            PCC.MaxLift(),
            PCC.SumLift(2),
            PCC.ProductLift(2),
            PCC.PathDependentLift(1),
        )

        @test PCC.is_path_complete(PCC.graph(lift(g)), 1:2)
    end
end

@testset "duality is an involution on lifts and operations" begin
    for lift in (PCC.ForwardEdgeSplit(), PCC.MinLift(), PCC.CompositionLift(1))
        @test PCC.dual(PCC.dual(lift)) == lift
    end
    for op in (
        PCC.Addition(),
        PCC.Maximum(),
        PCC.Minimum(),
        PCC.Composition(),
        PCC.InverseComposition(),
    )
        @test PCC.dual(PCC.dual(op)) == op
    end
    @test PCC.dual(PCC.Minimum()) == PCC.Maximum()
    @test PCC.dual(PCC.Addition()) == PCC.Addition()
end

end # module
