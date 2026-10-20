module TestLiftIdentity

using Test
import PathCompleteCertificates as PCC

@testset "the identity lift is the graph, and its simulation the plain map" begin
    coarse = PCC.de_bruijn(1, 2)
    fine = PCC.de_bruijn(2, 2)
    lifted = PCC.lift(PCC.IdentityLift(), fine)

    @test PCC.graph(lifted) === fine
    @test PCC.origins(lifted) == collect(PCC.nodes(fine))
    @test PCC.requirements(PCC.IdentityLift()) == ()

    # De Bruijn of order one simulates order two by the last letter, not back.
    @test PCC.simulation(PCC.IdentityLift(), coarse, fine) == PCC.simulation(coarse, fine)
    @test PCC.simulation(PCC.IdentityLift(), coarse, fine) !== nothing
    @test PCC.simulation(PCC.IdentityLift(), fine, coarse) === nothing

    system = PCC.switched_system([[0.5 0.0; 0.0 0.5], [0.0 0.5; 0.5 0.0]])
    for template in (
        PCC.QuadraticTemplate(),
        PCC.ParallelFacesPolyhedralTemplate(1, 2),
        PCC.LinearCopositiveTemplate(),
    )
        @test PCC.is_valid(PCC.IdentityLift(), template, system)
    end
end

end # module
