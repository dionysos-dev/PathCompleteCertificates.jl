module TestGauges
using Test, LinearAlgebra, SetProg
using SumOfSquares
import PathCompleteCertificates as PCC
import Clarabel, HiGHS

# A user-defined family inherits the documented default capabilities.
struct UnknownSetFamily <: SetProg.AbstractVariable end

@testset "Native family capabilities" begin
    invertible = PCC.switched_system([[0.5 -0.1; 0.2 0.4]])
    singular = PCC.switched_system([[0.5 0.0; 0.0 0.0]])
    unknown = UnknownSetFamily()
    @test PCC.is_applicable(unknown, invertible)
    @test !PCC.is_closed_under(unknown, PCC.Addition(), invertible)
    @test !PCC.has_dual(unknown)
    @test_throws ArgumentError PCC.dual(unknown)

    ellipsoid = Ellipsoid(symmetric = true)
    # A domain on an ellipsoid is not a linear copositive family.
    domain = SetProg.Domain(ellipsoid, MOI.Nonnegatives)
    @test PCC.is_applicable(domain, invertible)

    x = SetProg.new_polyvars(2)
    polynomial = PolySet(symmetric = true, degree = 4, variables = x)
    polytope = Polytope(symmetric = true, dimension = 2)
    for (family, degree) in ((ellipsoid, 2), (polynomial, 4), (polytope, 1))
        @test PCC.is_applicable(family, invertible)
        @test PCC.homogeneity_degree(family) == degree
        @test PCC.is_closed_under(family, PCC.Addition(), invertible)
        @test !PCC.is_closed_under(family, PCC.Maximum(), invertible)
    end
    @test PCC.homogeneity_degree(SetProg.Sets.Ellipsoid(Symmetric([2.0 0.0; 0.0 3.0]))) == 2
    @test PCC.homogeneity_degree(SetProg.Sets.PolarPoint([1.0, 2.0])) == 1
    for operation in (PCC.Composition(), PCC.InverseComposition())
        @test PCC.is_closed_under(polynomial, operation, invertible)
        @test !PCC.is_closed_under(polynomial, operation, singular)
    end
    @test PCC.dual(ellipsoid) === ellipsoid
end

@testset "Homogeneous gauges" begin
    A = [0.5 0.0; 0.0 0.25]
    families = (
        Ellipsoid(symmetric = true),
        PCC.LinearCopositiveTemplate(),
        PCC.DualCopositiveTemplate(),
        only(PCC.ParallelFacesPolyhedralTemplate(1, 2)),
        only(PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(1)])),
    )
    x = SetProg.new_polyvars(2)
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

@testset "Normalization uses a native PSD or SOS remainder" begin
    x = SetProg.new_polyvars(2)
    for (family, dimension) in (
        (Ellipsoid(symmetric = true), 3),
        (PolySet(symmetric = true, degree = 4, variables = x), 2),
    )
        model = Model(optimizer_with_attributes(Clarabel.Optimizer, MOI.Silent() => true))
        S = PCC.add_function_variables!(model, family, dimension, 1)
        original = S.set
        PCC.add_normalization!(model, original, S)
        @test S.set.superset !== nothing
        @test original.superset === nothing
        @test isempty(SetProg.data(model).constraints)
        optimize!(model)
        @test termination_status(model) in (MOI.OPTIMAL, MOI.ALMOST_OPTIMAL)
        # Only the remainder is constrained; there is no second PSD/SOS cone.
        @test num_constraints(model; count_variable_in_set_constraints = true) == 1
        point = ones(dimension)
        @test PCC._gauge(value(S), point) >=
              PCC._gauge(PCC._unit_set(original), point) - 1e-6
    end
    # Keep normalization over each cone for piecewise ellipsoids; convex
    # polynomial families do not support the superset construction.
    partition = PCC.planar_conic_partition(1)
    for family in (
        Ellipsoid(symmetric = true, piecewise = partition),
        PolySet(symmetric = true, degree = 4, convex = true, variables = x),
    )
        model = Model()
        S = PCC.add_function_variables!(model, family, 2, 1)
        PCC.add_normalization!(model, S.set, S)
        @test S.set.superset === nothing
        @test length(SetProg.data(model).constraints) == 1
    end
end

@testset "SumOfSquaresTemplate infers its polynomial coordinates" begin
    for degree in 1:3, min_scale in (0.25, 1.0, 2.0)
        family = PCC.SumOfSquaresTemplate(degree; min_scale)
        family = PCC._with_dimension(family, 2)
        @test family isa SetProg.PolySet
        @test family.degree == 2degree
        @test length(family.variables) == 2
        @test PCC.homogeneity_degree(family) == 2degree
        @test PCC._gauge(family.superset, [2.0, 3.0]) ≈ min_scale * 13^degree
    end
    @test_throws ArgumentError PCC.SumOfSquaresTemplate(0)
    @test_throws ArgumentError PCC.SumOfSquaresTemplate(1; min_scale = 0)
    problem = PCC.StabilityProblem(PCC.switched_system([[0.5 0.0; 0.0 0.25]]))
    graph = PCC.de_bruijn(1, 1)
    for min_scale in (0.25, 2.0)
        family = PCC.SumOfSquaresTemplate(2; min_scale)
        model = Model(optimizer_with_attributes(Clarabel.Optimizer, MOI.Silent() => true))
        S = PCC.add_function_variables!(model, family, 2, 1)
        PCC.add_normalization!(model, S.set, S)
        optimize!(model)
        @test termination_status(model) in (MOI.OPTIMAL, MOI.ALMOST_OPTIMAL)
        @test isempty(SetProg.data(model).constraints)
        @test num_constraints(model; count_variable_in_set_constraints = true) == 1
        # The custom reference survives dimension filling and normalization.
        @test JuMP.constant(SetProg.sublevel_eval(S.variable, [2.0, 3.0])) ≈
              min_scale * 13^2
        certificate =
            PCC.certify(family, graph, problem; optimizer = Clarabel.Optimizer, rate = 0.6)
        @test PCC.is_feasible(certificate)
        @test certificate([1.0, 1.0]) >= min_scale * 4 - 1e-6
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
    x = SetProg.new_polyvars(2)
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
