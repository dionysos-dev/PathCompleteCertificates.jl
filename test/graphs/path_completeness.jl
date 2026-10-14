module TestGraphPathCompleteness

using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "Graph completeness" begin
    G1 = GraphAutomaton(3)
    for edge in [(1, 1, 1), (1, 2, 2), (2, 2, 1), (2, 3, 2), (3, 1, 1), (3, 3, 2)]
        add_transition!(G1, edge...)
    end

    @test PCC.is_complete(G1)
    @test !PCC.is_co_complete(G1)

    G2 = GraphAutomaton(3)
    for edge in [(1, 2, 1), (2, 3, 2), (3, 1, 1)]
        add_transition!(G2, edge...)
    end

    @test !PCC.is_complete(G2)
    @test !PCC.is_co_complete(G2)

    G3 = GraphAutomaton(3)
    for edge in [(1, 1, 1), (2, 1, 2), (2, 2, 1), (3, 2, 2), (3, 3, 1), (1, 3, 2)]
        add_transition!(G3, edge...)
    end

    @test PCC.is_complete(G3)
    @test PCC.is_co_complete(G3)
end

@testset "path-completeness is relative to an alphabet" begin
    # A graph that never mentions mode 2 reads every word over its own labels,
    # and reads nothing containing mode 2. The one-argument form cannot see the
    # difference, which is why the problem constructors pass the system's
    # alphabet.
    graph = GraphAutomaton(1)
    add_transition!(graph, 1, 1, 1)

    @test PCC.is_path_complete(graph)
    @test PCC.is_path_complete(graph, 1:1)
    @test !PCC.is_path_complete(graph, 1:2)

    de_bruijn = PCC.de_bruijn(2, 2)
    @test PCC.is_path_complete(de_bruijn, 1:2)
    @test !PCC.is_path_complete(de_bruijn, 1:3)

    # A graph with no node reads no word at all, not even over no mode.
    @test !PCC.is_path_complete(PCC.empty_graph(0), 1:2)
    @test !PCC.is_path_complete(PCC.empty_graph(0))
end

@testset "the subset construction reaches the empty set when a word is unreadable" begin
    # Example 3.2 of Abate, Debauche, Giacobbe & Roy (HSCC 2026): two 2s in a
    # row cannot be read, and the subset construction runs {1, 2} -> {1} -> ∅.
    graph = GraphAutomaton(2)
    add_transition!(graph, 1, 1, 1)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 2, 1, 2)

    states, _, reads_every_word =
        PCC._subset_construction(graph, 1:2, PCC._successors(graph); stop_at_empty = false)
    @test states == [Set([1, 2]), Set([1])]
    @test !reads_every_word
    @test !PCC.is_path_complete(graph, 1:2)

    # With the loop (2, 2, 2), {1, 2} is the only subset reached.
    add_transition!(graph, 2, 2, 2)

    states, _, reads_every_word =
        PCC._subset_construction(graph, 1:2, PCC._successors(graph); stop_at_empty = false)
    @test states == [Set([1, 2])]
    @test reads_every_word
    @test PCC.is_path_complete(graph, 1:2)
end

@testset "path-completeness is strictly weaker than completeness" begin
    # Philippe et al., Definitions II.1 and III.2: complete and co-complete are
    # *sufficient* conditions for path-completeness, not equivalent ones. Node 3
    # has no outgoing mode-2 edge and node 2 no incoming mode-1 edge, so the
    # graph is neither -- yet the subset construction from {1,2,3} visits only
    # {1} and {2} and never empties, so every word is readable.
    graph = GraphAutomaton(3)
    for edge in [(1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2), (3, 1, 1)]
        add_transition!(graph, edge...)
    end

    @test !PCC.is_complete(graph, 1:2)
    @test !PCC.is_co_complete(graph, 1:2)
    @test PCC.is_path_complete(graph, 1:2)

    # The converse direction, on the same alphabet: complete implies
    # path-complete, and so does co-complete.
    @test PCC.is_complete(PCC.de_bruijn(2, 2), 1:2)
    @test PCC.is_path_complete(PCC.de_bruijn(2, 2), 1:2)

    dual = PCC.dual(PCC.de_bruijn(2, 2))
    @test PCC.is_co_complete(dual, 1:2)
    @test !PCC.is_complete(dual, 1:2)
    @test PCC.is_path_complete(dual, 1:2)

    # A graph that genuinely cannot read a word: no mode-2 edge leaves node 2,
    # and node 2 is the only mode-1 successor, so "1 2" is unreadable.
    broken = GraphAutomaton(2)
    add_transition!(broken, 1, 2, 1)
    add_transition!(broken, 1, 1, 2)
    @test !PCC.is_path_complete(broken, 1:2)
end

end
