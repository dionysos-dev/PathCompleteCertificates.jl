module TestSimulate

# Simulation is the substrate for refutation, so the properties that matter are
# that it never produces a run the plant cannot take, and that a given word is
# reproduced exactly.

using Test
using HybridSystems
using Random
import PathCompleteCertificates as PCC
import LinearAlgebra

const A = [[0.5 0.0; 0.0 0.25], [0.0 1.0; -1.0 0.0]]
const SYSTEM = PCC.switched_system(A)

# Mode 2 may not follow mode 2.
const CONSTRAINT = GraphAutomaton(2)
add_transition!(CONSTRAINT, 1, 1, 1)
add_transition!(CONSTRAINT, 1, 2, 2)
add_transition!(CONSTRAINT, 2, 1, 1)
const CONSTRAINED = PCC.switched_system(A; automaton = CONSTRAINT)

@testset "a run follows the dynamics it was given" begin
    trajectory = PCC.simulate(SYSTEM, [1.0, 1.0], [1, 1, 2])

    @test length(trajectory) == 3
    @test PCC.switching(trajectory) == [1, 1, 2]
    @test length(PCC.states(trajectory)) == 4
    @test !PCC.has_input(trajectory)
    @test PCC.inputs(trajectory) === nothing

    visited = PCC.states(trajectory)
    @test visited[1] == [1.0, 1.0]
    for (step, mode) in enumerate(PCC.switching(trajectory))
        @test visited[step + 1] ≈ A[mode] * visited[step]
    end
end

@testset "a zero-step run is the initial state alone" begin
    trajectory = PCC.simulate(SYSTEM, [2.0, -1.0], 0)

    @test length(trajectory) == 0
    @test PCC.states(trajectory) == [[2.0, -1.0]]
    @test isempty(PCC.switching(trajectory))
end

@testset "random switching stays inside the automaton" begin
    # The point of the test: `rand(1:n)` would pass on SYSTEM and fail here.
    rng = MersenneTwister(1)

    for _ in 1:50
        word = PCC.switching(PCC.simulate(CONSTRAINED, [1.0, 1.0], 12; rng = rng))

        @test length(word) == 12
        @test all(in(1:2), word)
        # Mode 2 twice in a row is exactly what the automaton forbids.
        @test !any(word[k] == 2 && word[k + 1] == 2 for k in 1:(length(word) - 1))
    end
end

@testset "free switching does reach every mode" begin
    rng = MersenneTwister(2)
    word = PCC.switching(PCC.simulate(SYSTEM, [1.0, 1.0], 200; rng = rng))

    @test Set(word) == Set(1:2)
end

@testset "an inadmissible word is refused, not adjusted" begin
    @test_throws ArgumentError PCC.simulate(CONSTRAINED, [1.0, 1.0], [2, 2])
    @test_throws ArgumentError PCC.simulate(SYSTEM, [1.0, 1.0], [3])
    @test_throws ArgumentError PCC.simulate(SYSTEM, [1.0, 1.0, 1.0], 3)
    @test_throws ArgumentError PCC.simulate(SYSTEM, [1.0, 1.0], -1)

    # The same word is fine from the state that offers it.
    @test length(PCC.simulate(CONSTRAINED, [1.0, 1.0], [2, 1])) == 2
end

@testset "an open-loop run of a controlled system is refused" begin
    B = [reshape([0.0, 1.0], 2, 1), reshape([0.0, 1.0], 2, 1)]
    controlled = PCC.switched_system(A, B)

    # Underdetermined rather than silently u = 0.
    @test_throws ArgumentError PCC.simulate(controlled, [1.0, 1.0], 5)
end

@testset "the number type is not forced to Float64" begin
    exact = [[1 // 2 0 // 1; 0 // 1 1 // 4]]
    trajectory = PCC.simulate(PCC.switched_system(exact), [1 // 1, 1 // 1], [1, 1])

    @test eltype(first(PCC.states(trajectory))) == Rational{Int}
    @test PCC.states(trajectory)[3] == [1 // 4, 1 // 16]
end

end
