module TestSystems

using Test
import PathCompleteCertificates as PCC
import MathematicalSystems as MS

# Two modes on the plane, 1-D input.
const A_TEST = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
const B_TEST = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]

@testset "without an input" begin
    s = PCC.SwitchedLinearSystem(A_TEST)

    @test PCC.nmodes(s) == 2
    @test collect(PCC.modes(s)) == [1, 2]
    @test MS.statedim(s) == 2
    @test PCC.state_matrices(s) == A_TEST
    @test MS.state_matrix(s, 1) == A_TEST[1]
    @test MS.state_matrix(s, 2) == A_TEST[2]
    @test !MS.iscontrolled(s)
    @test PCC.constraint(s) === nothing
    @test s isa PCC.AbstractSwitchedSystem
end

@testset "with an input" begin
    s = PCC.SwitchedLinearControlSystem(A_TEST, B_TEST)

    @test MS.iscontrolled(s)
    @test MS.inputdim(s) == 1
    @test PCC.input_matrices(s) == B_TEST
    @test MS.input_matrix(s, 2) == B_TEST[2]
    @test s isa PCC.AbstractSwitchedSystem
end

@testset "element types are promoted, not silently mixed" begin
    # Integer A_TEST, floating-point B_TEST: both land in one element type, so downstream
    # code never has to handle a system whose matrices disagree.
    s = PCC.SwitchedLinearControlSystem([[1 0; 0 1]], [reshape([0.5, 0.5], 2, 1)])
    @test eltype(MS.state_matrix(s, 1)) == Float64
    @test eltype(MS.input_matrix(s, 1)) == Float64

    ints = PCC.SwitchedLinearSystem([[1 0; 0 1]])
    @test eltype(MS.state_matrix(ints, 1)) == Int
end

@testset "the standard MathematicalSystems predicates" begin
    plain = PCC.SwitchedLinearSystem(A_TEST)
    ctrl = PCC.SwitchedLinearControlSystem(A_TEST, B_TEST)

    @test !MS.iscontrolled(plain)
    @test MS.iscontrolled(ctrl)
    @test MS.islinear(plain) && MS.isaffine(plain)
    @test !MS.isnoisy(plain)

    # Theirs asks about state/input/noise sets; ours about switching sequences.
    # A_TEST switching constraint must not be reported as a state constraint.
    @test !MS.isconstrained(PCC.SwitchedLinearSystem(A_TEST; constraint = (:g,)))
end

@testset "a switching constraint is carried verbatim" begin
    # Any labelled digraph; the system only stores it.
    marker = (:some_graph,)
    s = PCC.SwitchedLinearSystem(A_TEST; constraint = marker)
    @test PCC.constraint(s) === marker
end

@testset "dimension errors are caught at construction" begin
    @test_throws ArgumentError PCC.SwitchedLinearSystem(typeof(A_TEST)())
    @test_throws ArgumentError PCC.SwitchedLinearSystem([[1.0 2.0 3.0]])       # not square
    @test_throws ArgumentError PCC.SwitchedLinearSystem([A_TEST[1], zeros(3, 3)])   # mixed dim
    @test_throws ArgumentError PCC.SwitchedLinearControlSystem(A_TEST, B_TEST[1:1])      # mode count
    @test_throws ArgumentError PCC.SwitchedLinearControlSystem(
        A_TEST,
        [reshape([1.0], 1, 1), B_TEST[2]],
    )
    @test_throws ArgumentError PCC.SwitchedLinearControlSystem(
        A_TEST,
        [B_TEST[1], zeros(2, 2)],
    )
end

end
