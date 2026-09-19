module TestSafety

using Test
import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra

# Anand, Jungers, Zamani & Allgöwer, CDC 2024: two modes on the plane, initial
# set ‖x‖ ≤ 4, unsafe set ‖x‖ ≥ 6.
const A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
const S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
const SU = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]

certificate(graph) = PCC.safety_certificate(
    PCC.QuadraticTemplate,
    graph,
    PCC.SafetyProblem(PCC.switched_system(A), S0, SU);
    optimizer = Clarabel.Optimizer,
)

@testset "the barrier is not the trivial one" begin
    res = certificate(PCC.de_bruijn(1, 2))
    @test res.feasible

    # A barrier is negative on the initial set and positive on the unsafe one,
    # so its matrix has eigenvalues of both signs. P = 0 would pass every other
    # test in this file.
    for P in res.P
        eigenvalues = LinearAlgebra.eigvals(LinearAlgebra.Symmetric(Matrix(P)))
        @test any(<(-1e-6), eigenvalues)
        @test any(>(1e-6), eigenvalues)
    end
end

@testset "the multipliers stay nonnegative" begin
    res = certificate(PCC.de_bruijn(1, 2))
    @test all(>=(-1e-8), res.gamma0)
    @test all(>=(-1e-8), res.gammau)
end

@testset "input-free systems only" begin
    B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]
    controlled = PCC.switched_system(A, B)
    @test_throws ArgumentError PCC.SafetyProblem(controlled, S0, SU)
end

@testset "the sets are validated" begin
    system = PCC.switched_system(A)
    @test_throws ArgumentError PCC.SafetyProblem(system, S0[1:2, 1:2], SU)   # wrong size
    @test_throws ArgumentError PCC.SafetyProblem(system, [1.0 2.0 3.0; 0 1 0; 0 0 1], SU)
end

end
