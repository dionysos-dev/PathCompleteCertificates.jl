
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
        PCC.QuadraticTemplate(),
        mode_1_only,
        problem,
        0.95;
        optimizer = OPTIMIZER,
    )

    @test_throws ArgumentError PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        mode_1_only,
        problem;
        optimizer = OPTIMIZER,
    )
end

@testset "a path-complete graph that is neither complete nor co-complete" begin
    # The check must not be stricter than the theory. Complete and co-complete
    # are sufficient conditions (Philippe et al., Definition III.2); this graph
    # is neither, yet reads every word, so it is a legitimate certificate
    # structure and synthesis has to accept it.
    contracting = PCC.switched_system([[0.5 0.0; 0.0 0.5], [0.4 0.0; 0.0 0.4]])
    problem = PCC.StabilityProblem(contracting)

    graph = GraphAutomaton(3)
    for edge in [(1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2), (3, 1, 1)]
        add_transition!(graph, edge...)
    end

    @test !PCC.is_complete(graph, 1:2)
    @test !PCC.is_co_complete(graph, 1:2)
    @test PCC.is_path_complete(graph, 1:2)

    result = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        graph,
        problem;
        optimizer = OPTIMIZER,
        rtol = 1e-2,
    )

    @test result.feasible
    @test 0.5 <= result.bound <= 0.52
end

@testset "quadratic stability" begin
    @test PCC.is_stable(PCC.QuadraticTemplate(), GRAPH, PROBLEM, 0.6; optimizer = OPTIMIZER)

    @test !PCC.is_stable(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM,
        0.4;
        optimizer = OPTIMIZER,
    )

    result = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
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
    # `V(x) = c'x` is homogeneous of degree 1, so its edge condition is
    # `V_dst(Ax) <= gamma * V_src(x)` and `gamma` is the contraction rate
    # directly. The driver used to raise every template's rate to the square,
    # which made this bound sqrt(rho(A)) = 0.707 rather than rho(A) = 0.5 --
    # `jsr_bound` returned different quantities for different templates.

    @test PCC.is_stable(
        PCC.LinearCopositiveTemplate(),
        GRAPH,
        PROBLEM,
        0.6;
        optimizer = OPTIMIZER,
    )

    @test !PCC.is_stable(
        PCC.LinearCopositiveTemplate(),
        GRAPH,
        PROBLEM,
        0.4;
        optimizer = OPTIMIZER,
    )

    result = PCC.jsr_bound(
        PCC.LinearCopositiveTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-2,
    )

    # rho(diag(0.5, 0.25)) = 0.5, and every template must agree on it.
    @test abs(result.bound - 0.5) <= 0.01
    @test result.feasible
end

@testset "every template agrees on the rate" begin
    # The point of `rate_exponent`: the same system and graph, three templates
    # of two different degrees, one answer.
    @test PCC.rate_exponent(PCC.QuadraticTemplate()) == 2
    @test PCC.rate_exponent(PCC.LinearCopositiveTemplate()) == 1
    @test PCC.rate_exponent(PCC.PolyhedralTemplate(2, 2)) == 1

    bounds = map((
        PCC.QuadraticTemplate(),
        PCC.LinearCopositiveTemplate(),
        PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2),
    )) do template
        PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3).bound
    end

    for bound in bounds
        @test abs(bound - 0.5) <= 0.01
    end
end

@testset "the conditioning cap is opt-in, because it changes the answer" begin
    # A rotation in coordinates stretched by 20: rho = 0.9, and the only
    # quadratic certificates have cond(P) = 400. The normalisation used to cap
    # that at 100 unconditionally, so `jsr_bound` returned 1.5 for a system
    # whose true rate is 0.9 and `is_stable` said false for a stable system.
    stretch = [1.0 0.0; 0.0 20.0]
    theta = pi / 4
    stretched =
        stretch * (0.9 * [cos(theta) -sin(theta); sin(theta) cos(theta)]) * inv(stretch)

    graph = GraphAutomaton(1)
    add_transition!(graph, 1, 1, 1)
    problem = PCC.StabilityProblem(PCC.switched_system([stretched]))

    default = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        graph,
        problem;
        optimizer = OPTIMIZER,
        rtol = 1e-3,
    )

    @test abs(default.bound - 0.9) <= 0.01
    @test PCC.is_stable(
        PCC.QuadraticTemplate(),
        graph,
        problem,
        0.95;
        optimizer = OPTIMIZER,
    )

    # The cap still available, and still conservative -- which is the point of
    # making the caller ask for it.
    capped = PCC.jsr_bound(
        PCC.QuadraticTemplate(; conditioning_bound = 100),
        graph,
        problem;
        optimizer = OPTIMIZER,
        rtol = 1e-3,
    )

    @test capped.bound > default.bound + 0.1
    @test capped.bound >= 0.9          # still a sound upper bound

    @test_throws ArgumentError PCC.QuadraticTemplate(; conditioning_bound = 0.5)
end

@testset "input validation" begin
    invalid_label_graph = GraphAutomaton(1)
    add_transition!(invalid_label_graph, 1, 1, 2)

    @test_throws ArgumentError PCC.stability_problem(
        PCC.QuadraticTemplate(),
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
