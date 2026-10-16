module TestGauges
using Test, LinearAlgebra, SetProg
using SumOfSquares, DynamicPolynomials
import PathCompleteCertificates as PCC
import Clarabel, HiGHS

@testset "Homogeneous gauges" begin
    A = [0.5 0.0; 0.0 0.25]
    families = (
        Ellipsoid(symmetric = true),
        PCC.LinearCopositiveTemplate(),
        PCC.DualCopositiveTemplate(),
        only(PCC.ParallelFacesPolyhedralTemplate(1, 2)),
        only(PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(1)])),
    )
    @polyvar x[1:2]
    families = (
        families...,
        PolySet(symmetric = true, degree = 4, variables = x),
        PolySet(symmetric = true, degree = 2, variables = x, convex = true),
    )
    problem = PCC.StabilityProblem(PCC.switched_system([A]))
    for family in families, rate in (0.6, 0.4)
        optimizer =
            family isa Union{Ellipsoid, PolySet} ? Clarabel.Optimizer : HiGHS.Optimizer
        model = Model(optimizer_with_attributes(optimizer, MOI.Silent() => true))
        S = PCC.add_function_variables!(model, family, 2, 1)
        PCC.add_normalization!(model, S.set, S)
        PCC.add_decrease!(
            model,
            family,
            S,
            S,
            A;
            scale = rate^PCC.homogeneity_degree(family),
        )
        optimize!(model)
        if rate > 0.5
            @test termination_status(model) in (MOI.OPTIMAL, MOI.ALMOST_OPTIMAL)
            fitted = PCC.solution_value(family, S)
            @test PCC.node_value(problem, fitted, [1.0, 1.0]) > 0
            @test PCC.node_value(problem, fitted, [2.0, 2.0]) ≈
                  2^PCC.homogeneity_degree(family) *
                  PCC.node_value(problem, fitted, [1.0, 1.0])
            if family isa PolySet
                @test_throws ArgumentError PCC.decrease_slack(family, fitted, fitted, A)
            else
                @test PCC.decrease_slack(
                    family,
                    fitted,
                    fitted,
                    A;
                    scale = rate^PCC.homogeneity_degree(family),
                ) >= -1e-6
            end
        else
            @test termination_status(model) in (MOI.INFEASIBLE, MOI.ALMOST_INFEASIBLE)
        end
    end
end

@testset "Gauge data and duality" begin
    @test_throws ArgumentError PCC.DualCopositiveTemplate(min_weight = 0)
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate([zeros(2, 2)])
    @test_throws ArgumentError PCC.ConicPolyhedralTemplate([])
    @test_throws DimensionMismatch PCC._with_dimension(
        only(PCC.ParallelFacesPolyhedralTemplate(1, 2)),
        3,
    )
    @test PCC._supports_dual(Ellipsoid(symmetric = true))
    @test PCC._dual_family(PCC.LinearCopositiveTemplate()) == PCC.DualCopositiveTemplate()
    @test PCC._dual_family(PCC.DualCopositiveTemplate()) == PCC.LinearCopositiveTemplate()
    family = PCC.DualCopositiveTemplate(min_weight = 2)
    @test PCC._dual_family(PCC._dual_family(family)) == family
    @test PCC.homogeneity_degree([
        PCC.DualCopositiveTemplate(),
        PCC.LinearCopositiveTemplate(),
    ]) == 1
    ell = SetProg.Sets.Ellipsoid(Symmetric([2.0 0.0; 0.0 3.0]))
    @test PCC._dual_value(PCC._dual_value(ell)).Q ≈ ell.Q
    simplex = PCC.LinearCopositiveFunction([2.0, 3.0])
    @test PCC._dual_value(PCC._dual_value(simplex)).set.a == simplex.set.a
end

@testset "Gauge normalization and edge directions" begin
    @polyvar x[1:2]
    family = PCC._with_dimension(PolySet(symmetric = true, degree = 6), 2; variables = x)
    @test family.variables == x
    @test PCC._gauge(PCC._unit_set(family), [2.0, 3.0]) ≈ 13^3
    @test_throws DimensionMismatch PCC._with_dimension(
        PolySet(symmetric = true, degree = 4, variables = x),
        3,
    )
    @test_throws ArgumentError PCC._with_dimension(Ellipsoid(), 2)
    @test_throws ArgumentError PCC.homogeneity_degree(SetProg.AbstractVariable[])
    @test_throws ArgumentError PCC.homogeneity_degree([
        Ellipsoid(symmetric = true),
        PCC.DualCopositiveTemplate(),
    ])
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(0, 2)
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(1, 2; min_weight = 0)
    model = Model(optimizer_with_attributes(Clarabel.Optimizer, MOI.Silent() => true))
    S = PCC.add_function_variables!(model, Ellipsoid(symmetric = true), 2, 1)
    PCC.add_normalization!(model, S.set, S; conditioning_bound = 10)
    PCC.add_decrease!(model, S.set, S, S, zeros(2, 2); scale = 0)
    optimize!(model)
    @test termination_status(model) in (MOI.OPTIMAL, MOI.ALMOST_OPTIMAL)
    Q = value(S).Q
    @test minimum(eigvals(Q)) >= 1 - 1e-6
    @test maximum(eigvals(Q)) <= 10 + 1e-6
    @test_throws ArgumentError PCC.add_normalization!(
        model,
        S.set,
        S;
        conditioning_bound = 0.5,
    )
    @test_throws ArgumentError PCC.add_decrease!(
        model,
        S.set,
        S,
        S,
        zeros(2, 2);
        scale = -1,
    )
    model = Model(optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true))
    B = PCC.add_function_variables!(model, PCC.DualCopositiveTemplate(), 2, 1)
    @test_throws ArgumentError PCC.add_normalization!(
        model,
        B.set,
        B;
        conditioning_bound = 10,
    )
    PCC.add_normalization!(model, B.set, B)
    PCC.add_decrease!(model, B.set, B, B, Matrix{Float64}(I, 2, 2); scale = 0)
    optimize!(model)
    @test termination_status(model) == MOI.INFEASIBLE
    simplex = PCC.LinearCopositiveFunction([2.0, 3.0])
    box = PCC.DualCopositiveFunction([4.0, 5.0])
    @test PCC.decrease_slack(
        PCC.LinearCopositiveTemplate(),
        simplex,
        PCC.LinearCopositiveFunction([1.0, 2.0]),
        [0.5 0.2; 0.0 0.5],
    ) ≈ 1.5
    @test PCC.decrease_slack(
        PCC.DualCopositiveTemplate(),
        box,
        PCC.DualCopositiveFunction([3.0, 4.0]),
        [0.5 0.2; 0.0 0.5],
    ) ≈ 0
    G = [2.0 0.0; 0.0 1.0]
    parallelotope = PCC.ParallelFacesPolyhedralFunction(G, [1.0, 4.0])
    @test PCC._gauge(parallelotope, [3.0, 2.0]) ≈ 6
    @test !PCC._supports_dual(only(PCC.ParallelFacesPolyhedralTemplate([G])))
end

end
