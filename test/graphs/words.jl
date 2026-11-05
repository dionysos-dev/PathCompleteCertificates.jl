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

    expanded = PCC.expanded_form(g)

    @test expanded isa GraphAutomaton
    @test PCC.n_nodes(expanded) == 2            # one silent node for the two-letter word
    @test PCC.n_edges(expanded) == 3
    @test !PCC.has_words(expanded)

    # Factor sense: "2" is a factor of the path label "12", but "22" is a factor
    # of no path label, since every 2 is followed by a 1. So neither the graph
    # nor its expanded form reads every word over {1, 2}, and both agree.
    @test !PCC.is_path_complete(g, 1:2)
    @test !PCC.is_path_complete(expanded, 1:2)

    # One loop reading 2 on its own, and every word is a factor.
    PCC.add_edge!(g, 1, 1, [2])
    @test PCC.is_path_complete(g, 1:2)
    @test PCC.is_path_complete(PCC.expanded_form(g), 1:2)

    # A graph with one mode per edge expands to itself.
    letter = PCC.de_bruijn(1, 2)
    @test PCC.expanded_form(letter) === letter
end

@testset "a word graph is complete or co-complete only as a graph with one mode per edge" begin
    g = PCC.WordGraph(1)
    PCC.add_edge!(g, 1, 1, [1])
    PCC.add_edge!(g, 1, 1, [2])

    @test !PCC.has_words(g)
    @test PCC.is_complete(g, 1:2)
    @test PCC.is_co_complete(g, 1:2)
    @test PCC._letter_graph(g, "a test") isa GraphAutomaton
    @test PCC.n_edges(PCC._letter_graph(g, "a test")) == 2

    PCC.add_edge!(g, 1, 1, [1, 2])
    @test !PCC.is_complete(g, 1:2)
    @test PCC.is_path_complete(g, 1:2)
    @test_throws ArgumentError PCC._letter_graph(g, "a test")
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

    # The edge correspondence at some edges.
    primal = PCC.de_bruijn(1, 2)
    edge_list = PCC.outgoing_edges(primal, 1)
    dualised, image = PCC._dual_with_images(primal)
    images = [image[e] for e in edge_list]
    @test length(images) == length(edge_list)
    for (e, f) in zip(edge_list, images)
        @test PCC.source(f) == PCC.dest(e) && PCC.dest(f) == PCC.source(e)
        @test PCC.label(dualised, f) == PCC.label(primal, e)
    end
end

end # module
