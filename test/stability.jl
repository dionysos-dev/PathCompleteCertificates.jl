
module TestStability

using Test
import PathCompleteCertificates as PCC
import SCS

const GRAPH = PCC.Graph(2, [(1, 2, 1), (2, 1, 1)])
const A = [[0.5 0.0; 0.0 0.25]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)
const OPTIMIZER = SCS.Optimizer

@testset "quadratic stability" begin
    @test PCC.is_stable(PCC.QuadraticTemplate, GRAPH, PROBLEM, 0.6; optimizer = OPTIMIZER)

    @test !PCC.is_stable(PCC.QuadraticTemplate, GRAPH, PROBLEM, 0.4; optimizer = OPTIMIZER)

    bound = PCC.jsr_bound(
        PCC.QuadraticTemplate,
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-2,
    )

    @test 0.5 <= bound <= 0.51
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

    bound = PCC.jsr_bound(
        PCC.LinearCopositiveTemplate,
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-2,
    )

    @test abs(bound - sqrt(0.5)) <= 0.01
end

@testset "input validation" begin
    invalid_label_graph = PCC.Graph(1, [(1, 1, 2)])

    @test_throws ArgumentError PCC.stability_problem(
        PCC.QuadraticTemplate,
        invalid_label_graph,
        PROBLEM,
        1.0;
        optimizer = OPTIMIZER,
    )
end

end
