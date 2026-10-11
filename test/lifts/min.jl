module TestLiftMin

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

# Four graphs of the HSCC 2023 capsule (Debauche, Della Rossa & Jungers).
const G0 = graph([(1, 1, 1), (1, 1, 2)], 1)
const G1 = graph(
    [
        (1, 2, 1),
        (2, 1, 1),
        (1, 3, 1),
        (3, 1, 2),
        (1, 4, 2),
        (4, 1, 1),
        (1, 5, 2),
        (5, 1, 2),
    ],
    5,
)
const G2 = graph(
    [
        (1, 3, 2),
        (1, 4, 2),
        (2, 1, 1),
        (2, 2, 1),
        (3, 3, 2),
        (3, 4, 2),
        (4, 2, 1),
        (4, 1, 1),
    ],
    4,
)
const G4 = graph(
    [
        (1, 2, 1),
        (2, 4, 1),
        (3, 2, 1),
        (4, 3, 1),
        (4, 5, 1),
        (5, 1, 1),
        (1, 4, 2),
        (1, 3, 2),
        (2, 1, 2),
        (3, 2, 2),
        (4, 5, 2),
        (5, 1, 2),
    ],
    5,
)
const GRAPHS = (G0, G1, G2, G4)

@testset "the min lift, the max lift as its dual, and their subsets" begin
    g = PCC.de_bruijn(1, 2)
    lifted = PCC.lift(PCC.MinLift(), g)
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
    x = PCC.graph(PCC.lift(PCC.MaxLift(), g))
    index = PCC.successors(g)
    subsets = PCC.origins(lifted)
    for (a, A) in enumerate(subsets), (b, B) in enumerate(subsets), i in 1:2
        expected = all(bb -> any(bb in get(index, (aa, i), Int[]) for aa in A), B)
        @test ((a, b, i) in edgeset(x)) == expected
    end

    @test_throws ArgumentError PCC.lift(PCC.MinLift(), PCC.de_bruijn(4, 2))
end

@testset "the relation decides what the explicit lift exhibits (Debauche, Thms. 8.1, 8.5)" begin
    for G in GRAPHS,
        H in GRAPHS,
        (L, dualise) in ((PCC.MinLift(), false), (PCC.MaxLift(), true))

        relation = PCC.simulation(L, G, H)
        lifted = PCC.lift(L, G)
        map = PCC.simulation(PCC.graph(lifted), H)

        @test (relation === nothing) == (map === nothing)
        relation === nothing && continue

        # The relation is a map into the subsets, and it preserves the edges.
        index = Dict(subset => k for (k, subset) in enumerate(PCC.origins(lifted)))
        lifted_edges = edgeset(PCC.graph(lifted))
        for e in PCC.edges(H)
            @test (
                index[relation[PCC.source(e)]],
                index[relation[PCC.dest(e)]],
                PCC.label(H, e),
            ) in lifted_edges
        end
    end

    # G4 is complete and co-complete, so both lifts of it simulate G0 by the
    # full node set; G1 and G2 are neither simulated by G0 nor simulate it.
    @test PCC.simulation(PCC.MinLift(), G4, G0) == [[1, 2, 3, 4, 5]]
    @test PCC.simulation(PCC.MaxLift(), G4, G0) == [[1, 2, 3, 4, 5]]
    @test PCC.simulation(PCC.MinLift(), G1, G0) === nothing
    @test PCC.simulation(PCC.MinLift(), G2, G0) === nothing
    @test PCC.simulation(PCC.MaxLift(), G1, G0) === nothing
end

@testset "duality is an involution on lifts and operations" begin
    for L in (PCC.IdentityLift(), PCC.MinLift(), PCC.SumLift(2), PCC.CompositionLift(1))
        @test PCC.dual(PCC.dual(L)) == L
    end
    @test PCC.dual(PCC.MinLift()) == PCC.MaxLift()
    @test PCC.dual(PCC.SumLift(2)) == PCC.SumLift(2)
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
