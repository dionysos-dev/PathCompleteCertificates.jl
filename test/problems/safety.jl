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

certificate(graph) = PCC.certify(
    PCC.QuadraticTemplate(),
    graph,
    PCC.SafetyProblem(PCC.switched_system(A), S0, SU);
    optimizer = Clarabel.Optimizer,
)

@testset "the barrier is not the trivial one" begin
    res = certificate(PCC.de_bruijn(1, 2))
    @test PCC.is_feasible(res)

    # A barrier is negative on the initial set and positive on the unsafe one,
    # so its matrix has eigenvalues of both signs. P = 0 would pass every other
    # test in this file.
    for V in PCC.functions(res)
        eigenvalues = LinearAlgebra.eigvals(LinearAlgebra.Symmetric(Matrix(V)))
        @test any(<(-1e-6), eigenvalues)
        @test any(>(1e-6), eigenvalues)
    end
end

@testset "the multipliers stay nonnegative" begin
    res = certificate(PCC.de_bruijn(1, 2))
    @test all(>=(-1e-8), res.initial_multipliers)
    @test all(>=(-1e-8), res.unsafe_multipliers)
end

@testset "the separation margin is a real quantity" begin
    # `eps` used to be pinned to zero: it sat on the edge condition, where the
    # constant direction of the homogeneous lift telescopes around any cycle to
    # force `eps <= 0`. It now sits only on the initial- and unsafe-set
    # conditions, where it can be positive, with the barriers scale-normalised
    # so that maximising it is bounded.
    for order in 1:3
        res = certificate(PCC.de_bruijn(order, 2))

        @test PCC.is_feasible(res)
        @test res.margin > 1e-6

        # The normalisation that makes `max eps` bounded.
        for V in PCC.functions(res)
            @test maximum(abs, Matrix(V)) <= 1 + 1e-6
        end
    end
end

@testset "an unseparable instance is reported as one" begin
    # Unsafe set ‖x‖ >= 1 overlaps the initial set ‖x‖ <= 4, so no barrier can
    # exist. The margin has to come back at zero and `feasible` has to say so --
    # with `eps` pinned to zero for every instance, this could not be told
    # apart from a genuine certificate.
    overlapping = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -1.0]

    res = PCC.certify(
        PCC.QuadraticTemplate(),
        PCC.de_bruijn(1, 2),
        PCC.SafetyProblem(PCC.switched_system(A), S0, overlapping);
        optimizer = Clarabel.Optimizer,
    )

    @test res.margin <= 1e-6
    @test !PCC.is_feasible(res)
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
