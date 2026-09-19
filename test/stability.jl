
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

@testset "a graph that is not path-complete for the system is rejected" begin
    # The soundness condition, and the one the old `is_complete` could not see:
    # this graph never mentions mode 2, so it constrains nothing about a mode
    # that diverges at rate 3. Before the alphabet argument it returned a JSR
    # bound of 0.906 for a system whose JSR is at least 3.
    two_modes = PCC.switched_system([[0.9 0.0; 0.0 0.9], [3.0 0.0; 0.0 3.0]])
    problem = PCC.StabilityProblem(two_modes)

    mode_1_only = GraphAutomaton(1)
    add_transition!(mode_1_only, 1, 1, 1)

    @test PCC.is_path_complete(mode_1_only)          # for its own alphabet
    @test !PCC.is_path_complete(mode_1_only, 1:2)    # not for the system's

    @test_throws ArgumentError PCC.is_stable(
        PCC.QuadraticTemplate,
        mode_1_only,
        problem,
        0.95;
        optimizer = OPTIMIZER,
    )

    @test_throws ArgumentError PCC.jsr_bound(
        PCC.QuadraticTemplate,
        mode_1_only,
        problem;
        optimizer = OPTIMIZER,
    )
end

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

    # A system with an input is not a stability problem.
    B = [reshape([1.0, 0.0], 2, 1)]
    @test_throws ArgumentError PCC.StabilityProblem(PCC.switched_system(A, B))
end

end
