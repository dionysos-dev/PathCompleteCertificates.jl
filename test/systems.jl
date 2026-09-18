module TestSystems

using Test
import PathCompleteCertificates as PCC
import HybridSystems as HS
import MathematicalSystems as MS

# Two modes, 2-D state, 1-D input.
const A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
const B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

"Reset maps of `s` keyed by mode -- `resetmap` is indexed by the transition's event."
function maps_by_mode(s)
    out = Dict{Int, Any}()
    for t in HS.transitions(s.automaton)
        out[HS.event(s.automaton, t)] = HS.resetmap(s, t)
    end
    return out
end

@testset "input-free path is untouched" begin
    s = PCC.switched_system(A)
    # Must stay exactly what HybridSystems builds, so anything already consuming
    # a plain switched system keeps working.
    @test s isa HS.DiscreteSwitchedLinearSystem
    @test !PCC.has_input(s)
    @test PCC.mode_matrices(s) == A

    rm = maps_by_mode(s)
    @test length(rm) == 2
    @test rm[1] isa MS.LinearMap
end

@testset "with an input" begin
    s = PCC.switched_system(A, B)
    @test PCC.has_input(s)

    rm = maps_by_mode(s)
    for σ in 1:2
        @test rm[σ] isa MS.LinearControlMap
        @test rm[σ].A == A[σ]
        @test rm[σ].B == B[σ]
    end

    Amat, Bmat = PCC.mode_matrices(s)
    @test Amat == A
    @test Bmat == B

    # Switching stays autonomous: the mode is not ours to choose, the input is.
    # HybridSystems has no accessor for this -- `switchings(s, i, j)` is about
    # paths -- so the field is the only route.
    @test all(sw isa HS.AutonomousSwitching for sw in s.switchings)
end

@testset "the matrices are on the transitions, not the modes" begin
    s = PCC.switched_system(A, B)
    # One discrete state, two self-loops labelled 1 and 2. The mode carries no
    # dynamics at all, which is why mode_matrices has to exist.
    @test HS.nstates(s.automaton) == 1
    @test HS.ntransitions(s.automaton) == 2
    @test HS.mode(s, 1) isa MS.ContinuousIdentitySystem
    @test sort([HS.event(s.automaton, t) for t in HS.transitions(s.automaton)]) == [1, 2]
end

@testset "constrained switching" begin
    # Mode 2 may not follow mode 2 -- an automaton the default cannot express.
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 2, 2)
    HS.add_transition!(g, 2, 1, 1)

    s = PCC.switched_system(A, B; automaton = g)
    @test HS.nstates(s.automaton) == 2
    @test HS.ntransitions(s.automaton) == 3
    @test PCC.has_input(s)

    # Constrained switching also works without an input.
    plain = PCC.switched_system(A; automaton = g)
    @test !PCC.has_input(plain)
end

@testset "dimension errors are caught at construction" begin
    @test_throws ArgumentError PCC.switched_system(typeof(A)(), typeof(B)())
    @test_throws ArgumentError PCC.switched_system(A, B[1:1])                # mode count
    @test_throws ArgumentError PCC.switched_system([[1.0 2.0 3.0]], B[1:1])  # not square
    @test_throws ArgumentError PCC.switched_system(A, [reshape([1.0], 1, 1), B[2]])  # B rows
    @test_throws ArgumentError PCC.switched_system(A, [B[1], zeros(2, 2)])   # input dim
end

end
