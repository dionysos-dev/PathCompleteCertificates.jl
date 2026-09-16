module TestHybridSystemsExt

using Test
import PathCompleteCertificates as PCC
import MathematicalSystems as MS

# Two modes on the plane, 1-D input.
const A_TEST = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
const B_TEST = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

# Loading these two is what activates the extension.
import HybridSystems as HS

@testset "the extension is loaded" begin
    @test Base.get_extension(PCC, :PathCompleteCertificatesHybridSystemsExt) !== nothing
end

@testset "round trip, without an input" begin
    s = PCC.SwitchedLinearSystem(A_TEST)
    hs = HS.HybridSystem(s)

    # The encoding HybridSystems expects: one discrete state, one self-loop per
    # mode, dynamics on the transitions rather than on the modes.
    @test hs isa HS.DiscreteSwitchedLinearSystem
    @test HS.nstates(hs.automaton) == 1
    @test HS.ntransitions(hs.automaton) == 2
    @test HS.mode(hs, 1) isa MS.ContinuousIdentitySystem

    back = PCC.SwitchedLinearSystem(hs)
    @test PCC.nmodes(back) == 2
    @test MS.state_matrix(back, 1) == A_TEST[1]
    @test MS.state_matrix(back, 2) == A_TEST[2]
    @test !MS.iscontrolled(back)
end

@testset "round trip, with an input" begin
    s = PCC.SwitchedLinearControlSystem(A_TEST, B_TEST)
    hs = HS.HybridSystem(s)

    back = PCC.SwitchedLinearControlSystem(hs)
    @test MS.iscontrolled(back)
    for σ in 1:2
        @test MS.state_matrix(back, σ) == A_TEST[σ]
        @test MS.input_matrix(back, σ) == B_TEST[σ]
    end
end

@testset "a constrained system keeps its automaton" begin
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 2, 2)
    HS.add_transition!(g, 2, 1, 1)

    s = PCC.SwitchedLinearSystem(A_TEST; constraint = g)
    hs = HS.HybridSystem(s)
    @test HS.nstates(hs.automaton) == 2
    @test HS.ntransitions(hs.automaton) == 3

    back = PCC.SwitchedLinearSystem(hs)
    @test PCC.constraint(back) === g
end

@testset "arbitrary switching round-trips to nothing, not to a one-state graph" begin
    hs = HS.HybridSystem(PCC.SwitchedLinearSystem(A_TEST))
    @test PCC.constraint(PCC.SwitchedLinearSystem(hs)) === nothing
end

@testset "a genuine hybrid automaton is refused, not silently truncated" begin
    control = HS.HybridSystem(PCC.SwitchedLinearControlSystem(A_TEST, B_TEST))
    # Reading a system *with* an input as one without would drop B on the floor.
    @test_throws ArgumentError PCC.SwitchedLinearSystem(control)

    plain = HS.HybridSystem(PCC.SwitchedLinearSystem(A_TEST))
    @test_throws ArgumentError PCC.SwitchedLinearControlSystem(plain)
end

end
