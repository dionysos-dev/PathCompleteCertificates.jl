module TestLiftProduct

using Test
using HybridSystems
import PathCompleteCertificates as PCC

edgeset(g) = Set(
    (PCC.source(e), PCC.dest(e), collect(PCC.letters(PCC.label(g, e)))) for
    e in PCC.edges(g)
)

# The capsule's G_1 and G_4 (Debauche, Della Rossa & Jungers, HSCC 2023).
function graph(edges, n)
    g = GraphAutomaton(n)
    for (a, b, l) in edges
        add_transition!(g, a, b, l)
    end
    return g
end
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

@testset "folding one edge forward writes words on the edges" begin
    g = PCC.de_bruijn(1, 2)
    edge = first(PCC.outgoing_edges(g, 1, 1))     # the self-loop of node 1 reading 1
    lifted = PCC.ForwardEdgeProduct()(g, edge)
    w = PCC.graph(lifted)

    @test w isa PCC.WordGraph
    @test PCC.scope(PCC.ForwardEdgeProduct()) isa PCC.Local
    @test PCC.n_nodes(w) == 2
    @test PCC.origins(lifted) == [1, 2]

    # (1,1,1) becomes (1,1,[1,1]) and (1,2,[1,2]); the three other edges stay.
    @test edgeset(w) ==
          Set([(1, 1, [1, 1]), (1, 2, [1, 2]), (1, 2, [2]), (2, 1, [1]), (2, 2, [2])])
    @test PCC.is_path_complete(w, 1:2)
    @test !PCC.is_letter_graph(w)
end

@testset "forward and backward products at every edge are the 2-product lift" begin
    for g in (G1, G4)
        everywhere = collect(PCC.edges(g))
        forward = PCC.graph(PCC.ForwardEdgeProduct()(g, everywhere))
        backward = PCC.graph(PCC.BackwardEdgeProduct()(g, everywhere))
        product = PCC.graph(PCC.ProductLift(2)(g))

        @test edgeset(forward) == edgeset(backward) == edgeset(product)
        @test all(e -> PCC.word_length(product, e) == 2, PCC.edges(product))
        @test PCC.is_path_complete(product, 1:2)

        # Self-dual.
        @test edgeset(PCC.dual(product)) ==
              edgeset(PCC.graph(PCC.ProductLift(2)(PCC.dual(g))))
    end

    @test PCC.n_edges(PCC.graph(PCC.ProductLift(2)(G1))) == 20
    @test PCC.n_edges(PCC.graph(PCC.ProductLift(2)(G4))) == 29
end

@testset "the product lift of length T reads every path of length T" begin
    one = PCC.seed(OneStateAutomaton(2))
    for T in 1:3
        lifted = PCC.ProductLift(T)(one)
        w = PCC.graph(lifted)
        @test PCC.n_nodes(w) == 1
        @test PCC.n_edges(w) == 2^T
        @test all(e -> PCC.word_length(w, e) == T, PCC.edges(w))
        @test PCC.is_path_complete(w, 1:2)
    end

    @test PCC.scope(PCC.ProductLift(2)) isa PCC.Global
    @test_throws ArgumentError PCC.ProductLift(0)
end

@testset "folding into a dead end is refused" begin
    g = GraphAutomaton(2)
    e = add_transition!(g, 1, 2, 1)
    add_transition!(g, 1, 1, 2)

    @test_throws ArgumentError PCC.ForwardEdgeProduct()(g, e)
end

@testset "a product graph certifies the same rate as its expanded form" begin
    import Clarabel

    A = [0.69 .* [0.0 1.0; -1.0 0.0], 0.69 .* [1.0 1.0; 0.0 1.0]]
    problem = PCC.StabilityProblem(PCC.switched_system(A))
    one = PCC.seed(OneStateAutomaton(2))
    lifted = PCC.ProductLift(2)(one)
    w = PCC.graph(lifted)
    expanded, _ = PCC.expanded_form(w)

    on_words = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        w,
        problem;
        optimizer = Clarabel.Optimizer,
        rtol = 1e-5,
    )
    on_letters = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        expanded,
        problem;
        optimizer = Clarabel.Optimizer,
        rtol = 1e-5,
    )

    # Debauche, Prop. 7.70: equal for a composition-closed template, and the
    # word graph solves it with one node function instead of three.
    @test isapprox(on_words.rate, on_letters.rate; rtol = 1e-3)
    @test PCC.n_nodes(w) == 1
    @test PCC.n_nodes(expanded) == 1 + 4

    # Slacks and the cycle bound read the words too: the bracket is nonempty.
    @test length(PCC.edge_slacks(on_words)) == 4
    @test PCC.jsr_lower_bound(on_words; atol = 1e-4) > 0
    @test PCC.jsr_lower_bound(on_words; atol = 1e-4) <= on_words.rate + 1e-6

    # The structural test is not proved with words, and says so.
    @test_throws ArgumentError PCC.is_jsr_exact(on_words)

    # Safety and aggregation need a letter graph, and say so.
    @test_throws ArgumentError on_words([1.0, 0.0])
end

end # module
