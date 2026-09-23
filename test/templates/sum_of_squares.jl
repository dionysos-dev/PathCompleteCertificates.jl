module TestSumOfSquares

# The sum-of-squares template lives in a package extension, so this file is the
# only one that loads the polynomial stack.
#
# The anchor is that degree 1 reproduces `QuadraticTemplate` exactly: a
# sum-of-squares polynomial parametrised by degree-1 monomials *is* x'Px with
# P psd, so the two must agree to solver tolerance. Anything else means the
# scaling or the substitution is wrong.

using Test
using HybridSystems
using SumOfSquares, DynamicPolynomials
import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

@polyvar x[1:2]

# A rotation and a shear: no quadratic attains the joint spectral radius.
const A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))

const MEMORYLESS = GraphAutomaton(1)
add_transition!(MEMORYLESS, 1, 1, 1)
add_transition!(MEMORYLESS, 1, 1, 2)

@testset "the extension is what supplies the methods" begin
    @test Base.get_extension(PCC, :PathCompleteCertificatesSumOfSquaresExt) !== nothing
end

@testset "the template validates its own data" begin
    @test_throws ArgumentError PCC.SumOfSquaresTemplate(0, x)
    @test_throws ArgumentError PCC.SumOfSquaresTemplate(2, typeof(x[1])[])

    @test PCC.rate_exponent(PCC.SumOfSquaresTemplate(1, x)) == 2
    @test PCC.rate_exponent(PCC.SumOfSquaresTemplate(3, x)) == 6
end

@testset "degree 1 reproduces the quadratic template" begin
    quadratic = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        MEMORYLESS,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    )
    sos = PCC.jsr_bound(
        PCC.SumOfSquaresTemplate(1, x),
        MEMORYLESS,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    )

    @test PCC.is_feasible(quadratic)
    @test PCC.is_feasible(sos)
    @test abs(sos.rate - quadratic.rate) <= 1e-3
end

@testset "raising the degree tightens the bound" begin
    rates = map((1, 2, 3)) do degree
        PCC.jsr_bound(
            PCC.SumOfSquaresTemplate(degree, x),
            MEMORYLESS,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-4,
        ).rate
    end

    # Parrilo and Jadbabaie: the bound is non-increasing in the degree.
    @test rates[2] <= rates[1] + 1e-6
    @test rates[3] <= rates[2] + 1e-6

    # And strictly better here, since no quadratic attains this JSR.
    @test rates[2] < rates[1] - 1e-2
end

@testset "the fitted function is callable and homogeneous" begin
    degree = 2
    certificate = PCC.jsr_bound(
        PCC.SumOfSquaresTemplate(degree, x),
        MEMORYLESS,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-3,
    )

    V = only(PCC.functions(certificate))

    @test V isa PCC.SumOfSquaresFunction
    @test V([1.0, 1.0]) > 0
    @test V([0.0, 0.0]) ≈ 0 atol = 1e-8

    # V(cx) = c^(2 degree) V(x).
    @test V([2.0, 3.0]) ≈ 2.0^(2degree) * V([1.0, 1.5]) rtol = 1e-6

    # `certificate(x)` is the aggregation over one node, so the same number.
    @test certificate([1.0, 1.0]) ≈ V([1.0, 1.0]) rtol = 1e-8
end

@testset "the template and the system must agree on the dimension" begin
    @polyvar y[1:3]

    @test_throws ArgumentError PCC.jsr_bound(
        PCC.SumOfSquaresTemplate(1, y),
        MEMORYLESS,
        PROBLEM;
        optimizer = OPTIMIZER,
    )
end

@testset "the edge inequality holds where it was imposed" begin
    certificate = PCC.jsr_bound(
        PCC.SumOfSquaresTemplate(2, x),
        MEMORYLESS,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-3,
    )

    V = only(PCC.functions(certificate))
    scale = certificate.rate^PCC.rate_exponent(PCC.SumOfSquaresTemplate(2, x))

    # The constraint is built with the map divided rather than the inequality
    # scaled; this checks the two are the same inequality.
    for point in ([1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [1.0, -2.0], [-0.5, 3.0])
        for map in A
            @test scale * V(point) - V(map * point) >= -1e-6
        end
    end
end

end
