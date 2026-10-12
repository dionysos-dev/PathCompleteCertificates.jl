module TestGraphWords

using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "a word graph reads words and a graph with one mode per edge reads modes" begin
    g = PCC.WordGraph(2)
    e1 = PCC.add_edge!(g, 1, 2, [1, 2])
    e2 = PCC.add_edge!(g, 2, 1, 1)

    @test g isa PCC.WordGraph
    @test PCC.label(g, e1) == [1, 2]
    @test PCC.label(g, e2) == [1]
    @test PCC._word_length(g, e1) == 2
    @test PCC._word_length(g, e2) == 1
    @test PCC.has_words(g)
    @test sort(PCC.alphabet(g)) == [1, 2]

    letter = PCC.de_bruijn(1, 2)
    @test !PCC.has_words(letter)
    @test PCC.letters(PCC.label(letter, first(PCC.edges(letter)))) isa Tuple

    # A graph with one mode per edge refuses a longer word, and accepts one of length one.
    @test_throws ArgumentError PCC.add_edge!(letter, 1, 1, [1, 2])
    @test PCC.label(letter, PCC.add_edge!(letter, 1, 1, [2])) == 2
end

@testset "the expanded form reads the same language with one mode per edge" begin
    g = PCC.WordGraph(1)
    PCC.add_edge!(g, 1, 1, [1, 2])
    PCC.add_edge!(g, 1, 1, 1)

    expanded, origins = PCC.expanded_form(g)

    @test expanded isa GraphAutomaton
    @test PCC.n_nodes(expanded) == 2            # one silent node for the two-letter word
    @test PCC.n_edges(expanded) == 3
    @test origins == [1, 0]
    @test !PCC.has_words(expanded)

    # Factor sense: "2" is a factor of the path label "12", but "22" is a factor
    # of no path label -- every 2 is followed by a 1 -- so the graph reads the
    # language of neither {1, 2} nor its expanded form, and both agree.
    @test !PCC.is_path_complete(g, 1:2)
    @test !PCC.is_path_complete(expanded, 1:2)

    # One loop reading 2 on its own, and every word is a factor.
    PCC.add_edge!(g, 1, 1, [2])
    @test PCC.is_path_complete(g, 1:2)
    @test PCC.is_path_complete(first(PCC.expanded_form(g)), 1:2)

    # A graph with one mode per edge expands to itself.
    letter = PCC.de_bruijn(1, 2)
    same, ids = PCC.expanded_form(letter)
    @test same === letter
    @test ids == [1, 2]
end

@testset "a word graph is complete or co-complete only as a graph with one mode per edge" begin
    g = PCC.WordGraph(1)
    PCC.add_edge!(g, 1, 1, [1])
    PCC.add_edge!(g, 1, 1, [2])

    @test !PCC.has_words(g)
    @test PCC.is_complete(g, 1:2)
    @test PCC.is_co_complete(g, 1:2)
    @test PCC._letter_graph(g) isa GraphAutomaton
    @test PCC.n_edges(PCC._letter_graph(g)) == 2

    PCC.add_edge!(g, 1, 1, [1, 2])
    @test !PCC.is_complete(g, 1:2)
    @test PCC.is_path_complete(g, 1:2)
    @test_throws ArgumentError PCC._letter_graph(g)
end

@testset "the dual reverses edges and words" begin
    g = PCC.WordGraph(2)
    PCC.add_edge!(g, 1, 2, [1, 2])
    PCC.add_edge!(g, 2, 1, 3)

    d = PCC.dual(g)
    labels = Set((PCC.source(e), PCC.dest(e), PCC.label(d, e)) for e in PCC.edges(d))
    @test labels == Set([(2, 1, [2, 1]), (1, 2, [3])])

    dd = PCC.dual(d)
    @test Set((PCC.source(e), PCC.dest(e), PCC.label(dd, e)) for e in PCC.edges(dd)) ==
          Set((PCC.source(e), PCC.dest(e), PCC.label(g, e)) for e in PCC.edges(g))

    # On a graph with one mode per edge, the dual De Bruijn graph is the dual of the primal one.
    for k in 1:2
        primal = PCC.de_bruijn(k, 2)
        co = PCC.dual(PCC.de_bruijn(k, 2))
        edgeset(h) =
            Set((PCC.source(e), PCC.dest(e), PCC.label(h, e)) for e in PCC.edges(h))
        @test edgeset(PCC.dual(primal)) == edgeset(co)
    end

    # Path-completeness is preserved by duality.
    @test PCC.is_path_complete(PCC.dual(PCC.de_bruijn(2, 2)), 1:2)

    # The edge correspondence at some edges.
    primal = PCC.de_bruijn(1, 2)
    chosen = PCC.outgoing_edges(primal, 1)
    dualised, images = PCC.dual(primal, chosen)
    @test length(images) == length(chosen)
    for (e, f) in zip(chosen, images)
        @test PCC.source(f) == PCC.dest(e) && PCC.dest(f) == PCC.source(e)
        @test PCC.label(dualised, f) == PCC.label(primal, e)
    end
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

    @test PCC.outdegree(g, 1) == 2
    @test PCC.indegree(g, 1) == 2
end

end # module
