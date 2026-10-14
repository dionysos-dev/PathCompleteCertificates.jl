module TestGraphDeBruijn

using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "De Bruijn graphs" begin
    complete = PCC.de_bruijn(2, 2)
    @test PCC.n_nodes(complete) == 4
    @test PCC.n_edges(complete) == 8
    @test PCC.is_complete(complete)
    @test !PCC.is_co_complete(complete)

    for edge in PCC.edges(complete)
        @test PCC.label(complete, edge) in (1, 2)
        @test PCC.outdegree(complete, PCC.source(edge)) == 2
    end

    co_complete = PCC.dual(PCC.de_bruijn(2, 2))
    @test PCC.n_nodes(co_complete) == 4
    @test PCC.n_edges(co_complete) == 8
    @test !PCC.is_complete(co_complete)
    @test PCC.is_co_complete(co_complete)

    @test_throws ArgumentError PCC.de_bruijn(-1, 2)
    @test_throws ArgumentError PCC.de_bruijn(2, 0)
end

@testset "order zero is the common graph: one node with a loop per mode" begin
    one = PCC.de_bruijn(0, 3)
    @test PCC.n_nodes(one) == 1
    @test PCC.n_edges(one) == 3
    @test sort(PCC.alphabet(one)) == 1:3
    @test PCC.is_complete(one) && PCC.is_co_complete(one)

    A = [[0.5 0.0; 0.0 0.5], [0.0 0.5; 0.5 0.0], [0.5 0.5; 0.0 0.5]]
    system = PCC.switched_system(A)
    common = PCC.common_graph(system)
    @test PCC.n_nodes(common) == 1
    @test sort([PCC.label(common, e) for e in PCC.edges(common)]) == 1:3
    @test PCC.is_path_complete(common, 1:PCC.n_modes(system))

    # A system on a restricting automaton is refused.
    constraint = GraphAutomaton(2)
    add_transition!(constraint, 1, 1, 1)
    add_transition!(constraint, 1, 2, 2)
    add_transition!(constraint, 2, 1, 1)
    @test_throws ArgumentError PCC.common_graph(
        HybridSystems.discreteswitchedsystem(A[1:2], constraint),
    )
end

end
