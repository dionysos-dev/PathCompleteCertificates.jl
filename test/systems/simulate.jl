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

    # One input per step: neither missing nor left over.
    @test_throws ArgumentError PCC.simulate(s, x0, modes; u = u[1:1])
    @test_throws ArgumentError PCC.simulate(s, x0, modes; u = [u; [[0.0]]])
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

@testset "a random switching sequence" begin
    s = PCC.switched_system(A)
    rng = Random.MersenneTwister(1)

    x0 = [1.0, 2.0]

    trajectory = PCC.simulate(s, x0, 5; rng = rng)
    modes = PCC.switching(trajectory)

    @test length(modes) == 5
    @test all(σ -> σ in (1, 2), modes)
    # Replaying the drawn sequence reproduces the run exactly.
    @test PCC.states(PCC.simulate(s, x0, modes)) == PCC.states(trajectory)

    # With an input, the same draw.
    controlled = PCC.switched_system(A, B)
    run = PCC.simulate(controlled, x0, 20; u = x -> [0.0], rng = Random.MersenneTwister(1))
    @test length(PCC.switching(run)) == 20

    @test_throws ArgumentError PCC.simulate(s, x0, -1)
end

@testset "a system with constrained switching is refused" begin
    g = HS.GraphAutomaton(2)
    HS.add_transition!(g, 1, 1, 1)
    HS.add_transition!(g, 1, 2, 2)
    HS.add_transition!(g, 2, 1, 1)
    constrained = HS.discreteswitchedsystem(A, g)

    @test_throws ArgumentError PCC.simulate(constrained, [1.0, 2.0], 3)
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

    # An integer system driven by a real input, given as inputs or as a law.
    integer = PCC.switched_system([[1 0; 0 1]], [reshape([1, 0], 2, 1)])
    by_inputs = PCC.simulate(integer, [1, 1], [1]; u = [[0.5]])
    by_law = PCC.simulate(integer, [1, 1], [1]; u = x -> [x[1] / 2])

    @test PCC.states(by_inputs)[2] == [1.5, 1.0]
    @test PCC.states(by_law) == PCC.states(by_inputs)
end

@testset "a mismatched x0 is named, not left to the matmul" begin
    s = PCC.switched_system(A)

    @test_throws ArgumentError PCC.simulate(s, [1.0, 2.0, 3.0], [1])
end

end
