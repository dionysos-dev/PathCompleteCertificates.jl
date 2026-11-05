module TestLiftDual

using Test
import PathCompleteCertificates as PCC

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
