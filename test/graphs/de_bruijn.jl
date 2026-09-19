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

    co_complete = PCC.de_bruijn(2, 2; orientation = :co_complete)
    @test PCC.n_nodes(co_complete) == 4
    @test PCC.n_edges(co_complete) == 8
    @test !PCC.is_complete(co_complete)
    @test PCC.is_co_complete(co_complete)

    @test_throws ArgumentError PCC.de_bruijn(0, 2)
    @test_throws ArgumentError PCC.de_bruijn(2, 0)
    @test_throws ArgumentError PCC.de_bruijn(2, 2; orientation = :invalid)
end
