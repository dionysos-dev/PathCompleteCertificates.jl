module TestLinearCopositive

using Test
using LinearAlgebra
using SetProg
import PathCompleteCertificates as PCC
import HiGHS

const OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
const A = [[0.5 0.1; 0.0 0.25], [0.3 0.0; 0.1 0.4]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)
const GRAPH = PCC.common_graph(2)
const FAMILY = PCC.LinearCopositiveTemplate()

@testset "Copositive compatibility constructors" begin
    @test FAMILY isa SetProg.Domain{<:SetProg.Polytope}
    @test FAMILY.domain === MOI.Nonnegatives
    @test FAMILY.dimension === nothing
    @test PCC.homogeneity_degree(FAMILY) == 1
    @test PCC._with_dimension(FAMILY, 2).dimension == 2
    @test_throws DimensionMismatch PCC._with_dimension(
        Domain(Polytope(symmetric = true), MOI.Nonnegatives(3)),
        2,
    )
    fitted = PCC.LinearCopositiveFunction([2.0, 3.0])
    @test fitted isa SetProg.Sets.Intersection
    @test fitted.set isa SetProg.Sets.PolarPoint
    @test fitted.set.a == [2.0, 3.0]
    @test PCC.node_value(PROBLEM, fitted, [1.0, 1.0]) == 5
    @test PCC.node_value(PROBLEM, fitted, [2.0, 2.0]) == 10
    @test PCC.node_value(PROBLEM, fitted, [-1.0, 1.0]) == Inf
    @test PCC.is_applicable(FAMILY, SYSTEM)
    negative = PCC.switched_system([[-0.1 0.0; 0.0 0.25]])
    @test !PCC.is_applicable(FAMILY, negative)
    @test PCC.is_closed_under(FAMILY, PCC.Addition(), SYSTEM)
    @test !PCC.is_closed_under(FAMILY, PCC.Maximum(), SYSTEM)
    @test PCC.is_closed_under(FAMILY, PCC.Composition(), SYSTEM)
    @test !PCC.is_closed_under(FAMILY, PCC.InverseComposition(), SYSTEM)
    diagonal = PCC.switched_system([[0.5 0.0; 0.0 0.25]])
    @test PCC.is_closed_under(FAMILY, PCC.InverseComposition(), diagonal)
    @test_throws ArgumentError PCC.certify(
        FAMILY,
        PCC.common_graph(1),
        PCC.StabilityProblem(negative);
        optimizer = OPTIMIZER,
        rate = 0.6,
    )
end

@testset "Copositive normalization and edge inequalities" begin
    for (rate, feasible) in ((0.6, true), (0.4, false))
        certificate = PCC.certify(FAMILY, GRAPH, PROBLEM; optimizer = OPTIMIZER, rate)
        @test PCC.is_feasible(certificate) == feasible
        feasible || continue
        V = only(PCC.functions(certificate))
        @test all(>=(1 - 1e-7), V.set.a)
        @test certificate([1.0, 1.0]) >= 2 - 1e-7
        @test certificate([-1.0, 1.0]) == Inf
        @test all(>=(-1e-7), PCC.edge_slacks(certificate))
        for map in A, x in ([1.0, 0.0], [0.0, 1.0], [0.5, 2.0])
            @test rate * certificate(x) - certificate(map * x) >= -1e-7
        end
        for (edge, slack) in zip(PCC.edges(GRAPH), PCC.edge_slacks(certificate))
            map = A[only(PCC.letters(PCC.label(GRAPH, edge)))]
            @test slack ≈ minimum(rate * V.set.a - map' * V.set.a)
        end
        @test PCC.decrease_slack(FAMILY, V, V, [-0.5 0.0; 0.0 0.25]) == -Inf
    end
    bound = PCC.jsr_bound(FAMILY, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)
    @test PCC.is_feasible(bound)
    @test abs(bound.rate - 0.5) <= 1e-3
    @test all(>=(-1e-6), PCC.edge_slacks(bound))
    graph = PCC.de_bruijn(1, 2)
    per_node = fill(FAMILY, PCC.n_nodes(graph))
    certificate = PCC.certify(per_node, graph, PROBLEM; optimizer = OPTIMIZER, rate = 0.6)
    @test PCC.is_feasible(certificate)
    @test length(PCC.functions(certificate)) == 2
    @test all(>=(-1e-7), PCC.edge_slacks(certificate))
    @test certificate([1.0, 1.0]) >= 2 - 1e-7
end

@testset "Copositive native variable helpers" begin
    for (map, feasible) in ((zeros(2, 2), true), (Matrix{Float64}(I, 2, 2), false))
        model = Model(OPTIMIZER)
        S = PCC.add_function_variables!(model, FAMILY, 2, 1)
        @test S isa SetProg.SetVariableRef
        PCC.add_normalization!(model, S.set, S)
        PCC.add_decrease!(model, S.set, S, S, map; scale = 0)
        optimize!(model)
        @test termination_status(model) == (feasible ? MOI.OPTIMAL : MOI.INFEASIBLE)
        if feasible
            @test PCC.solution_value(FAMILY, S) isa SetProg.Sets.Intersection
        end
    end
    model = Model(OPTIMIZER)
    S = PCC.add_function_variables!(model, FAMILY, 2, 1)
    @test_throws ArgumentError PCC.add_normalization!(
        model,
        S.set,
        S;
        conditioning_bound = 10,
    )
    @test_throws ArgumentError PCC.add_decrease!(model, S.set, S, S, A[1]; scale = -1)
end

@testset "Dual copositive normalization selects dual modeling" begin
    for min_weight in (1.0, 3.0), rate in (0.6, 0.4)
        family = PCC.DualCopositiveTemplate(; min_weight)
        model = PCC.optimization_model(family, GRAPH, PROBLEM; optimizer = OPTIMIZER, rate)
        optimize!(model)
        @test termination_status(model) == (rate == 0.6 ? MOI.OPTIMAL : MOI.INFEASIBLE)
        @test SetProg.data(model).space == SetProg.DualSpace
        @test PCC.has_dual(family)
        @test PCC.dual(PCC.dual(family)) == family
        if rate == 0.6
            V = value(only(model[:stability_V]))
            @test V isa SetProg.Sets.PolarOf{<:PCC._LinearCopositiveSet}
            @test all(>=(min_weight - 1e-7), polar(V).set.a)
            @test PCC.node_value(PROBLEM, V, [1.0, 1.0]) > 0
            @test PCC.node_value(PROBLEM, V, [2.0, 2.0]) ≈
                  2 * PCC.node_value(PROBLEM, V, [1.0, 1.0])
            @test PCC.decrease_slack(family, V, V, A[1]; scale = rate) >= -1e-7
            dual_family = PCC.dual(family)
            dual_model = PCC.optimization_model(
                dual_family,
                PCC.dual(GRAPH),
                PCC.dual(PROBLEM);
                optimizer = OPTIMIZER,
                rate,
            )
            optimize!(dual_model)
            @test termination_status(dual_model) == MOI.OPTIMAL
            @test SetProg.data(dual_model).space == SetProg.PrimalSpace
            @test all(>=(min_weight - 1e-7), value(only(dual_model[:stability_V])).set.a)
        end
    end
    @test hash(PCC.DualCopositiveTemplate(min_weight = 1)) ==
          hash(PCC.DualCopositiveTemplate(min_weight = 1.0))
    @test_throws ArgumentError PCC.DualCopositiveTemplate(min_weight = 0)
    @test_throws ArgumentError PCC.DualCopositiveTemplate(min_weight = Inf)
    families = [PCC.DualCopositiveTemplate(min_weight = w) for w in (2, 3)]
    graph = PCC.de_bruijn(1, 2)
    c = PCC.certify(families, graph, PROBLEM; optimizer = OPTIMIZER, rate = 0.8)
    @test PCC.is_feasible(c)
    @test all(>=(-1e-7), PCC.edge_slacks(c))
    @test all(>=(-1e-7), PCC.edge_slacks(PCC.dual(c)))
    @test PCC.template(PCC.dual(PCC.dual(c))) == families
    @test PCC.dual(PCC.LinearCopositiveTemplate()) == PCC.DualCopositiveTemplate()
    for family in (PCC.LinearCopositiveTemplate(), PCC.DualCopositiveTemplate())
        c = PCC.certify(family, GRAPH, PROBLEM; optimizer = OPTIMIZER, rate = 0.8)
        @test PCC.is_feasible(c)
        dual = PCC.dual(c)
        @test all(>=(-1e-7), PCC.edge_slacks(dual))
        back = PCC.dual(dual)
        @test PCC.template(back) == family
        @test back([1.0, 1.0]) ≈ c([1.0, 1.0])
    end
end

@testset "Parallel faces retain orientations, symmetry, and minimum weights" begin
    for n in (2, 3)
        G = Matrix{Float64}(I, n, n)
        G[1, 2] = 0.5
        family = only(PCC.ParallelFacesPolyhedralTemplate([G]; min_weight = 2))
        problem =
            PCC.StabilityProblem(PCC.switched_system([0.5 * Matrix{Float64}(I, n, n)]))
        graph = PCC.common_graph(1)
        @test family.set isa SetProg.Polytope
        @test family.set.piecewise isa Polyhedra.Polyhedron
        @test !PCC.has_dual(family)
        for (rate, feasible) in ((0.6, true), (0.4, false))
            c = PCC.certify(family, graph, problem; optimizer = OPTIMIZER, rate)
            @test PCC.is_feasible(c) == feasible
            feasible || continue
            V = only(PCC.functions(c))
            @test V isa SetProg.Sets.PolarOf{<:PCC._LinearPolytope}
            inner = polar(V)
            w = [PCC._polytope_value(inner, G[i, :]) for i in 1:n]
            @test all(>=(2 - 1e-7), w)
            for x in (ones(n), collect(1.0:n), -ones(n))
                v = PCC.node_value(problem, V, x)
                @test v ≈ maximum(abs.(G * x) ./ w)
                @test v ≈ PCC.node_value(problem, V, -x)
            end
            @test all(>=(-1e-7), PCC.edge_slacks(c))
        end
    end
    matrices = [[1.0 0.5; 0.0 1.0], [2.0 0.0; 0.0 1.0]]
    families = PCC.ParallelFacesPolyhedralTemplate(matrices)
    graph = PCC.de_bruijn(1, 2)
    c = PCC.certify(families, graph, PROBLEM; optimizer = OPTIMIZER, rate = 0.9)
    @test PCC.is_feasible(c)
    @test all(>=(-1e-7), PCC.edge_slacks(c))
    @test !PCC.is_closed_under(families, PCC.Maximum(), SYSTEM)
    @test PCC.is_closed_under(fill(first(families), 2), PCC.Maximum(), SYSTEM)
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate([zeros(2, 2)])
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(1, 0)
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(1, 2; min_weight = 0)
    @test_throws DimensionMismatch PCC.ParallelFacesPolyhedralTemplate([
        ones(2, 2),
        ones(3, 3),
    ])
end

end
