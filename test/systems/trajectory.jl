module TestTrajectory

using Test
import PathCompleteCertificates as PCC

const STATES = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0]]
const WORD = [2, 1]

@testset "the accessors read what was stored" begin
    trajectory = PCC.Trajectory(STATES, WORD, nothing)

    @test PCC.states(trajectory) == STATES
    @test PCC.switching(trajectory) == WORD
    @test PCC.inputs(trajectory) === nothing
    @test !PCC.has_input(trajectory)

    # One fewer step than states, always.
    @test length(trajectory) == 2
    @test length(PCC.states(trajectory)) == length(trajectory) + 1
end

@testset "an input trajectory reports itself as one" begin
    applied = [[0.5], [-0.5]]
    trajectory = PCC.Trajectory(STATES, WORD, applied)

    @test PCC.has_input(trajectory)
    @test PCC.inputs(trajectory) == applied
end

@testset "the shape is validated on construction" begin
    # One state too few for the number of steps.
    @test_throws ArgumentError PCC.Trajectory([[1.0]], [1], nothing)
    @test_throws ArgumentError PCC.Trajectory(STATES, [1, 2, 3], nothing)

    # One input per step, or none at all.
    @test_throws ArgumentError PCC.Trajectory(STATES, WORD, [[1.0]])
end

@testset "the number type is carried, not forced" begin
    exact = PCC.Trajectory([[1 // 2], [1 // 4]], [1], nothing)

    @test eltype(first(PCC.states(exact))) == Rational{Int}
end

end
