module TestSimulate

using Test
import PathCompleteCertificates as PCC
import HybridSystems as HS
import Random

# Two modes, 2-D state, 1-D input.
const A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
const B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

@testset "uncontrolled" begin
    s = PCC.switched_system(A)
    x0 = [1.0, 2.0]
    modes = [1, 2, 1]

    trajectory = PCC.simulate(s, x0, modes)
    xs = PCC.states(trajectory)

    @test PCC.switching(trajectory) == modes
    @test !PCC.has_input(trajectory)
    @test length(trajectory) == length(modes)
    @test length(xs) == length(modes) + 1
    @test xs[1] == x0
    @test xs[2] == A[1] * x0
    @test xs[3] == A[2] * xs[2]
    @test xs[4] == A[1] * xs[3]
end

@testset "controlled, an input sequence" begin
    s = PCC.switched_system(A, B)
    x0 = [1.0, 2.0]
    modes = [1, 2]
    u = [[0.5], [-1.0]]

    trajectory = PCC.simulate(s, x0, modes; u = u)
    xs = PCC.states(trajectory)

    @test PCC.has_input(trajectory)
    @test PCC.inputs(trajectory) == u
    @test xs[1] == x0
    @test xs[2] == A[1] * x0 + B[1] * u[1]
    @test xs[3] == A[2] * xs[2] + B[2] * u[2]
end

@testset "controlled, a feedback law" begin
    s = PCC.switched_system(A, B)
    x0 = [1.0, 2.0]
    modes = [1, 2]
    K = [-0.1 0.0]
    u(x) = K * x

    trajectory = PCC.simulate(s, x0, modes; u = u)
    xs = PCC.states(trajectory)

    @test xs[1] == x0
    @test xs[2] == A[1] * x0 + B[1] * u(x0)
    @test xs[3] == A[2] * xs[2] + B[2] * u(xs[2])

    # The law was evaluated at the state it was applied to, and kept.
    @test PCC.inputs(trajectory) == [u(x0), u(xs[2])]
end

@testset "u required exactly when the system is controlled" begin
    controlled = PCC.switched_system(A, B)
    uncontrolled = PCC.switched_system(A)

    @test_throws ArgumentError PCC.simulate(controlled, [1.0, 2.0], [1, 2])
    @test_throws ArgumentError PCC.simulate(
        uncontrolled,
        [1.0, 2.0],
        [1, 2];
        u = [[0.0], [0.0]],
    )
end

@testset "an empty switching sequence returns just x0" begin
    s = PCC.switched_system(A)
    x0 = [1.0, 2.0]
    trajectory = PCC.simulate(s, x0, Int[])

    @test PCC.states(trajectory) == [x0]
    @test length(trajectory) == 0
end

@testset "a random switching sequence, unconstrained automaton" begin
    g = HS.GraphAutomaton(1)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 1, 2)
    s = PCC.switched_system(A; automaton = g)
    x0 = [1.0, 2.0]
    rng = Random.MersenneTwister(1)

    trajectory = PCC.simulate(s, x0, 5; rng = rng)
    modes = PCC.switching(trajectory)

    @test length(modes) == 5
    @test all(σ -> σ in (1, 2), modes)
    # Replaying the drawn sequence reproduces the run exactly.
    @test PCC.states(PCC.simulate(s, x0, modes)) == PCC.states(trajectory)
end

@testset "a random switching sequence respects a constrained automaton" begin
    # Mode 2 may not follow mode 2.
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 2, 2)
    HS.add_transition!(g, 2, 1, 1)

    s = PCC.switched_system(A, B; automaton = g)
    x0 = [1.0, 2.0]
    rng = Random.MersenneTwister(1)

    modes = PCC.switching(PCC.simulate(s, x0, 20; u = x -> [0.0], rng = rng))

    @test length(modes) == 20
    @test !any(k -> modes[k] == 2 && modes[k + 1] == 2, 1:(length(modes) - 1))
end

@testset "an exhausted automaton throws" begin
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 2, 1)
    s = PCC.switched_system(A; automaton = g)

    @test_throws ArgumentError PCC.simulate(s, [1.0, 2.0], 3)
end

@testset "a random sequence on a system built without a restriction" begin
    # The default `switched_system(A)` carries a `OneStateAutomaton`, not a
    # `GraphAutomaton`. Every other random-walk test here builds the automaton
    # by hand, so this most ordinary of calls was the one not covered.
    s = PCC.switched_system(A)
    rng = Random.MersenneTwister(1)

    modes = PCC.switching(PCC.simulate(s, [1.0, 2.0], 5; rng = rng))

    @test length(modes) == 5
    @test all(σ -> σ in (1, 2), modes)
end

@testset "the number type is promoted, not taken from x0" begin
    s = PCC.switched_system(A)

    # An integer x0 under real dynamics: storing the result back into a
    # `Vector{Int}` would throw an `InexactError` at the second step.
    xs = PCC.states(PCC.simulate(s, [1, 2], [1, 2]))

    @test eltype(first(xs)) == Float64
    @test xs[2] == A[1] * [1.0, 2.0]

    # An exact run stays exact.
    exact = PCC.switched_system([[1//2 0//1; 0//1 1//4]])
    run = PCC.simulate(exact, [1//1, 1//1], [1])

    @test eltype(first(PCC.states(run))) == Rational{Int}
end

@testset "a mismatched x0 is named, not left to the matmul" begin
    s = PCC.switched_system(A)

    @test_throws ArgumentError PCC.simulate(s, [1.0, 2.0, 3.0], [1])
end

end
