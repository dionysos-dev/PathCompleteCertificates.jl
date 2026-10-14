module TestSystems

using Test
import PathCompleteCertificates as PCC
import HybridSystems as HS
import MathematicalSystems as MS

# Two modes, 2-D state, 1-D input.
const A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
const B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

@testset "input-free path is untouched" begin
    s = PCC.switched_system(A)
    # Must stay exactly what HybridSystems builds, so anything already consuming
    # a plain switched system keeps working.
    @test s isa HS.DiscreteSwitchedLinearSystem
    @test !PCC.has_input(s)
    @test PCC.state_matrices(s) == A

    rm = PCC._maps_by_mode(s)
    @test length(rm) == 2
    @test rm[1] isa MS.LinearMap
end

@testset "with an input" begin
    s = PCC.switched_system(A, B)
    @test PCC.has_input(s)

    # One reset-map type, so one call always returns one parametrisation.
    # Emitting an affine or constrained map would silently return a different
    # type from the same call.
    @test PCC.has_input(s)

    rm = PCC._maps_by_mode(s)
    for σ in 1:2
        @test rm[σ] isa MS.LinearControlMap
        @test rm[σ].A == A[σ]
        @test rm[σ].B == B[σ]
    end

    Amat = PCC.state_matrices(s)
    Bmat = PCC.input_matrices(s)
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
    # dynamics at all, which is why state_matrices has to exist.
    @test HS.nstates(s.automaton) == 1
    @test HS.ntransitions(s.automaton) == 2
    @test HS.mode(s, 1) isa MS.ContinuousIdentitySystem
    @test sort([HS.event(s.automaton, t) for t in HS.transitions(s.automaton)]) == [1, 2]
end

@testset "the alias covers every system with an input" begin
    @test PCC.has_input(PCC.switched_system(A, B))
    @test !PCC.has_input(PCC.switched_system(A))
end

@testset "the number of modes, under arbitrary switching only" begin
    @test PCC.n_modes(PCC.switched_system(A)) == 2
    @test PCC.n_modes(PCC.switched_system(A, B)) == 2

    # A system built directly on a restricting automaton is refused.
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 2, 2)
    HS.add_transition!(g, 2, 1, 1)
    constrained = HS.discreteswitchedsystem(A, g)
    @test_throws ArgumentError PCC.n_modes(constrained)
    @test_throws ArgumentError PCC.state_matrices(constrained)
    @test_throws ArgumentError PCC.has_input(constrained)
end

@testset "A and B of different number types are promoted" begin
    s = PCC.switched_system([[1 0; 0 1]], [reshape([0.5, 0.0], 2, 1)])

    @test PCC.state_matrices(s) == [[1.0 0.0; 0.0 1.0]]
    @test PCC.input_matrices(s) == [reshape([0.5, 0.0], 2, 1)]
end

@testset "dimension errors are caught at construction" begin
    @test_throws ArgumentError PCC.switched_system(typeof(A)(), typeof(B)())
    @test_throws ArgumentError PCC.switched_system(A, B[1:1])                # mode count
    @test_throws ArgumentError PCC.switched_system([[1.0 2.0 3.0]], B[1:1])  # not square
    @test_throws ArgumentError PCC.switched_system(A, [reshape([1.0], 1, 1), B[2]])  # B rows
    @test_throws ArgumentError PCC.switched_system(A, [B[1], zeros(2, 2)])   # input dim
    @test_throws ArgumentError PCC.switched_system(A, [zeros(2, 0), zeros(2, 0)])  # no input

    # The same checks without an input.
    @test_throws ArgumentError PCC.switched_system(typeof(A)())
    @test_throws ArgumentError PCC.switched_system([[1.0 2.0 3.0]])           # not square
    @test_throws ArgumentError PCC.switched_system([A[1], ones(3, 3)])        # sizes differ
end

@testset "the product along a word, newest mode leftmost" begin
    s = PCC.switched_system(A)
    @test PCC.state_matrix(s, [1, 2]) == A[2] * A[1]
    @test PCC.state_matrix(s, [2, 2, 1]) == A[1] * A[2] * A[2]
    @test_throws ArgumentError PCC.state_matrix(s, Int[])
end

@testset "positive and invertible systems" begin
    @test PCC._is_positive(PCC.switched_system(A))
    @test !PCC._is_positive(PCC.switched_system([A[1], [0.0 -1.0; 1.0 0.0]]))
    @test PCC._is_invertible(PCC.switched_system(A))
    @test !PCC._is_invertible(PCC.switched_system([A[1], [1.0 0.0; 0.0 0.0]]))
end

@testset "the dual system refuses constrained switching" begin
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 2, 2)
    HS.add_transition!(g, 2, 1, 1)
    @test_throws ArgumentError PCC.dual(HS.discreteswitchedsystem(A, g))
end

end
