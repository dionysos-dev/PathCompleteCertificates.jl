module TestCertificate

# One result shape for every problem. Before this, stability returned
# (bound, V, feasible), safety (status, P, gamma0, gammau, eps, feasible) and
# optimal control (status, objective, P, K, feasible) -- the same concept named
# `V` in one and `P` in the others, `status` present in two of three, and a
# `feasible` field that stability set unconditionally to true.

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import JuMP
import LinearAlgebra

const OPTIMIZER = Clarabel.Optimizer

const GRAPH = GraphAutomaton(2)
add_transition!(GRAPH, 1, 2, 1)
add_transition!(GRAPH, 2, 1, 1)

const SYSTEM = PCC.switched_system([[0.5 0.0; 0.0 0.25]])
const PROBLEM = PCC.StabilityProblem(SYSTEM)

const STABILITY = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    GRAPH,
    PROBLEM;
    optimizer = OPTIMIZER,
    rtol = 1e-2,
)

@testset "the accessors are the interface" begin
    @test STABILITY isa PCC.Certificate
    @test PCC.is_feasible(STABILITY)
    @test length(PCC.functions(STABILITY)) == PCC.n_nodes(GRAPH)
    @test PCC.status(STABILITY) isa JuMP.MOI.TerminationStatusCode
    @test PCC.details(STABILITY).rate ≈ STABILITY.details.rate
end

@testset "a certificate is callable, and is the common function" begin
    x = [1.0, 2.0]

    @test STABILITY(x) ≈
          PCC.common(PCC.QuadraticTemplate(), GRAPH, PROBLEM, PCC.functions(STABILITY), x)

    # Positive away from the origin, zero at it -- it is a Lyapunov function.
    @test STABILITY(x) > 0
    @test STABILITY([0.0, 0.0]) ≈ 0 atol = 1e-8
end

@testset "every problem returns the same shape" begin
    S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
    Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]
    modes = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

    safety = PCC.safety_certificate(
        PCC.QuadraticTemplate(),
        PCC.de_bruijn(1, 2),
        PCC.SafetyProblem(PCC.switched_system(modes), S0, Su);
        optimizer = OPTIMIZER,
    )

    control = PCC.optimal_control_certificate(
        PCC.QuadraticTemplate(),
        PCC.de_bruijn(1, 2),
        PCC.OptimalControlProblem(
            PCC.switched_system(
                [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]],
                [[1.0; 0.0;;], [1.0; 0.0;;]],
            ),
            [1.0 0.0; 0.0 1.0],
            [1.0;;],
        );
        optimizer = JuMP.optimizer_with_attributes(
            Clarabel.Optimizer,
            "chordal_decomposition_enable" => false,
        ),
    )

    for certificate in (STABILITY, safety, control)
        @test certificate isa PCC.Certificate
        @test PCC.is_feasible(certificate)
        @test !isempty(PCC.functions(certificate))
        @test PCC.status(certificate) isa JuMP.MOI.TerminationStatusCode
        @test certificate([1.0, 1.0]) isa Real
    end

    # The problem-specific part, and only that, lives in `details`.
    @test keys(PCC.details(STABILITY)) == (:rate,)
    @test keys(PCC.details(safety)) == (:margin, :initial_multipliers, :unsafe_multipliers)
    @test keys(PCC.details(control)) == (:gains, :objective)
end

@testset "an infeasible solve still returns a certificate" begin
    # Rather than a differently-shaped tuple with `nothing` fields.
    overlapping = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -1.0]
    S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
    modes = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]

    res = PCC.safety_certificate(
        PCC.QuadraticTemplate(),
        PCC.de_bruijn(1, 2),
        PCC.SafetyProblem(PCC.switched_system(modes), S0, overlapping);
        optimizer = OPTIMIZER,
    )

    @test res isa PCC.Certificate
    @test !PCC.is_feasible(res)
end

@testset "show says what it is" begin
    text = sprint(show, STABILITY)

    @test occursin("StabilityProblem", text)
    @test occursin("QuadraticTemplate", text)
    @test occursin("feasible", text)
end

end
