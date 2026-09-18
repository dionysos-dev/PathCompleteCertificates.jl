
module TestStability

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel

const GRAPH = GraphAutomaton(2)
add_transition!(GRAPH, 1, 2, 1)
add_transition!(GRAPH, 2, 1, 1)
const A = [[0.5 0.0; 0.0 0.25]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)
const OPTIMIZER = Clarabel.Optimizer

@testset "quadratic stability" begin
    @test PCC.is_stable(PCC.QuadraticTemplate, GRAPH, PROBLEM, 0.6; optimizer = OPTIMIZER)

    @test !PCC.is_stable(PCC.QuadraticTemplate, GRAPH, PROBLEM, 0.4; optimizer = OPTIMIZER)

    result = PCC.jsr_bound(
        PCC.QuadraticTemplate,
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-2,
    )

    @test 0.5 <= result.bound <= 0.51
    @test result.feasible
    @test length(result.V) == 2
end

@testset "linear copositive stability" begin
    # For V(x) = c'x, the edge inequalities imply
    # gamma^2 >= rho(A), hence gamma >= sqrt(0.5).

    @test PCC.is_stable(
        PCC.LinearCopositiveTemplate,
        GRAPH,
        PROBLEM,
        0.8;
        optimizer = OPTIMIZER,
    )

    @test !PCC.is_stable(
        PCC.LinearCopositiveTemplate,
        GRAPH,
        PROBLEM,
        0.6;
        optimizer = OPTIMIZER,
    )

    result = PCC.jsr_bound(
        PCC.LinearCopositiveTemplate,
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-2,
    )

    @test abs(result.bound - sqrt(0.5)) <= 0.01
    @test result.feasible
end

@testset "input validation" begin
    invalid_label_graph = GraphAutomaton(1)
    add_transition!(invalid_label_graph, 1, 1, 2)

    @test_throws ArgumentError PCC.stability_problem(
        PCC.QuadraticTemplate,
        invalid_label_graph,
        PROBLEM,
        1.0;
        optimizer = OPTIMIZER,
    )
end

end
