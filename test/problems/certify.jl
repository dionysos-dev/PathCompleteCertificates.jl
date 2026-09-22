module TestCertify

# The seam itself: one `certify` per problem, one `optimization_model` per
# problem, and the failure path they share.

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import JuMP

const OPTIMIZER = Clarabel.Optimizer

const A = [[0.5 0.0; 0.0 0.25]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)
const GRAPH = PCC.de_bruijn(1, 1)

@testset "certify at a fixed rate" begin
    loose = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.9,
    )

    @test PCC.is_feasible(loose)
    @test loose.rate == 0.9
    @test length(PCC.functions(loose)) == PCC.n_nodes(GRAPH)
    @test loose([1.0, 1.0]) > 0
end

@testset "an infeasible rate yields a certificate, not an error" begin
    tight = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.1,
    )

    @test !PCC.is_feasible(tight)
    @test isempty(PCC.functions(tight))
    @test PCC.status(tight) isa JuMP.MOI.TerminationStatusCode

    # The requested rate is carried, so the caller can tell which solve failed.
    @test tight.rate == 0.1
end

@testset "a failed solve names no function type" begin
    # `functions` is empty, so there is no fitted function to take a type from.
    # Claiming one is how this used to report `QuadraticFunction` for a
    # template that was nothing of the kind -- reachable now that stability
    # accepts every template.
    template = PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2)
    tight = PCC.certify(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rate = 0.01)

    @test !PCC.is_feasible(tight)
    @test isempty(PCC.functions(tight))
    @test !any(f -> f isa PCC.QuadraticFunction, PCC.functions(tight))
end

@testset "jsr_bound agrees with certify at the rate it returns" begin
    bound = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-3,
    )

    @test PCC.is_feasible(bound)
    @test abs(bound.rate - 0.5) <= 0.01

    # The bisection ends in exactly this solve.
    direct = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = bound.rate,
    )
    @test PCC.is_feasible(direct)
end

@testset "optimization_model builds without solving" begin
    model = PCC.optimization_model(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM,
        0.9;
        optimizer = OPTIMIZER,
    )

    @test model isa JuMP.Model
    @test JuMP.termination_status(model) == JuMP.MOI.OPTIMIZE_NOT_CALLED
    @test JuMP.num_variables(model) > 0
end

@testset "optimal control has a model of its own now" begin
    B = [[1.0; 0.0;;], [1.0; 0.0;;]]
    system = PCC.switched_system([[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]], B)
    problem = PCC.OptimalControlProblem(system, [1.0 0.0; 0.0 1.0], [1.0;;])

    model = PCC.optimization_model(
        PCC.QuadraticTemplate(),
        PCC.de_bruijn(1, 2),
        problem;
        optimizer = OPTIMIZER,
    )

    @test model isa JuMP.Model
    @test JuMP.termination_status(model) == JuMP.MOI.OPTIMIZE_NOT_CALLED
    @test haskey(model, :optimal_control_S)
    @test haskey(model, :optimal_control_Y)
end

end
