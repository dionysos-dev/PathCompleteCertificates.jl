module TestSafety

using Test
import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra
import JuMP
import SetProg
import DynamicPolynomials
import SumOfSquares

# Anand, Jungers, Zamani & Allgöwer, CDC 2024: two modes on the plane, initial
# set ‖x‖ ≤ 4, unsafe set ‖x‖ ≥ 6.
const A = [[0.7 0.77; -0.49 0.84], [0.7 0.77; -0.49 0.56]]
const S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 16.0]
const SU = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -36.0]

homogeneous(V) = [V.Q V.b; V.b' V.β]

certificate(graph) = PCC.certify(
    PCC.QuadraticTemplate(),
    graph,
    PCC.SafetyProblem(PCC.switched_system(A), S0, SU);
    optimizer = Clarabel.Optimizer,
)

@testset "the barrier is not the trivial one" begin
    res = certificate(PCC.de_bruijn(1, 2))
    @test PCC.is_feasible(res)
    @test PCC.template(res) == PCC.QuadraticTemplate()
    @test all(>=(-1e-6), PCC.edge_slacks(res))
    for V in PCC.functions(res)
        @test PCC.node_value(PCC.problem(res), V, [0.0, 0.0]) < 0
        @test PCC.node_value(PCC.problem(res), V, [6.0, 0.0]) > 0
    end

    # A barrier is negative on the initial set and positive on the unsafe one,
    # so its matrix has eigenvalues of both signs. P = 0 would pass every other
    # test in this file.
    for V in PCC.functions(res)
        eigenvalues = LinearAlgebra.eigvals(LinearAlgebra.Symmetric(homogeneous(V)))
        @test any(<(-1e-6), eigenvalues)
        @test any(>(1e-6), eigenvalues)
    end
end

@testset "the multipliers stay nonnegative" begin
    res = certificate(PCC.de_bruijn(1, 2))
    @test all(>=(-1e-8), res.initial_multipliers)
    @test all(>=(-1e-8), res.unsafe_multipliers)
end

@testset "the separation margin is a real quantity" begin
    # The margin sits on the initial- and unsafe-set conditions only: on the
    # edges, the constant direction of the homogeneous lift would telescope
    # around any cycle and force it to zero.
    for order in 1:3
        res = certificate(PCC.de_bruijn(order, 2))

        @test PCC.is_feasible(res)
        @test res.margin > 1e-6

        # The normalisation that makes `max eps` bounded.
        for V in PCC.functions(res)
            @test maximum(abs, homogeneous(V)) <= 1 + 1e-6
        end
    end
end

@testset "an unseparable instance is reported as one" begin
    # Unsafe set ‖x‖ >= 1 overlaps the initial set ‖x‖ <= 4, so no barrier can
    # exist. The margin has to come back at zero and `feasible` has to say so --
    # with `eps` pinned to zero for every instance, this could not be told
    # apart from a genuine certificate.
    overlapping = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -1.0]

    res = PCC.certify(
        PCC.QuadraticTemplate(),
        PCC.de_bruijn(1, 2),
        PCC.SafetyProblem(PCC.switched_system(A), S0, overlapping);
        optimizer = Clarabel.Optimizer,
    )

    @test res.margin <= 1e-6
    @test !PCC.is_feasible(res)
end

@testset "input-free systems only" begin
    B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]
    controlled = PCC.switched_system(A, B)
    @test_throws ArgumentError PCC.SafetyProblem(controlled, S0, SU)
end

@testset "the sets are validated" begin
    system = PCC.switched_system(A)
    @test_throws ArgumentError PCC.SafetyProblem(system, S0[1:2, 1:2], SU)   # wrong size
    @test_throws ArgumentError PCC.SafetyProblem(system, [1.0 2.0 3.0; 0 1 0; 0 0 1], SU)
end

@testset "quadratic safety preserves the SDP" begin
    graph = PCC.de_bruijn(1, 2)
    problem = PCC.SafetyProblem(PCC.switched_system(A), S0, SU)
    model = PCC.optimization_model(
        PCC.QuadraticTemplate(),
        graph,
        problem;
        optimizer = Clarabel.Optimizer,
    )
    JuMP.optimize!(model)
    sets = model[:safety_sets]
    # Use the native variables to write the original matrix formulation.
    # No numerical solution comparison can detect a redundant PSD constraint.
    Ps = [homogeneous(S.variable) for S in sets]
    gamma0 = [m.variable for m in model[:safety_gamma0]]
    gammau = [m.variable for m in model[:safety_gammau]]
    eps = model[:safety_eps]
    reference = []
    I3 = Matrix{Float64}(LinearAlgebra.I, 3, 3)
    for i in PCC.nodes(graph)
        append!(
            reference,
            [
                -Ps[i] - gamma0[i] * S0 - eps * I3,
                Ps[i] - gammau[i] * SU - eps * I3,
                I3 - Ps[i],
                Ps[i] + I3,
            ],
        )
    end
    for edge in PCC.edges(graph)
        Ah = PCC._homogeneous_dynamics(A[only(PCC.letters(PCC.label(graph, edge)))])
        push!(reference, Ps[PCC.source(edge)] - Ah' * Ps[PCC.dest(edge)] * Ah)
    end
    # SetProg uses constant-first coordinates; PCC's original lift used last.
    perm = [3, 1, 2]
    canonical(M) = [convert(JuMP.AffExpr, M[i, j]) for j in 1:3 for i in 1:j]
    expected = [canonical(M[perm, perm]) for M in reference]
    actual = [
        JuMP.constraint_object(c).func for c in JuMP.all_constraints(
            model,
            Vector{JuMP.AffExpr},
            JuMP.MOI.PositiveSemidefiniteConeTriangle,
        )
    ]
    @test length(actual) == 4 * PCC.n_nodes(graph) + PCC.n_edges(graph)
    @test JuMP.num_variables(model) == 8 * PCC.n_nodes(graph) + 1
    @test length(JuMP.list_of_constraint_types(model)) == 2
    @test JuMP.num_constraints(model, JuMP.VariableRef, JuMP.MOI.GreaterThan{Float64}) ==
          2 * PCC.n_nodes(graph) + 1
    for matrix in expected
        index =
            findfirst(candidate -> all(JuMP.isequal_canonical.(candidate, matrix)), actual)
        @test index !== nothing
        index === nothing || deleteat!(actual, index)
    end
    @test isempty(actual)
    @test JuMP.objective_sense(model) == JuMP.MOI.MAX_SENSE
    @test JuMP.objective_function(model) == eps
end

@testset "polynomial safety" begin
    DynamicPolynomials.@polyvar x[1:2]
    problem = PCC.SafetyProblem(PCC.switched_system([[0.5 0.0; 0.0 0.5]]), S0, SU)
    families = (
        SetProg.PolySet(; degree = 2, variables = x),
        SetProg.PolySet(; degree = 0:2, variables = x),
        SetProg.PolySet(; degree = 4, variables = x),
        SetProg.PolySet(; degree = 0:4, variables = x),
        PCC.SumOfSquaresTemplate(2, x),
    )
    for family in families
        degree = maximum(family.degree)
        res = PCC.certify(
            family,
            PCC.de_bruijn(1, 1),
            problem;
            optimizer = Clarabel.Optimizer,
        )
        @test PCC.is_feasible(res)
        @test res.margin > 1e-6
        V = only(PCC.functions(res))
        @test V isa SetProg.Sets.PolySet
        @test V.degree == 0:degree
        @test PCC.node_value(problem, V, [0.0, 0.0]) < 0
        for angle in range(0, 2pi; length = 9)
            direction = [cos(angle), sin(angle)]
            @test PCC.node_value(problem, V, 4 * direction) < 0
            @test PCC.node_value(problem, V, 6 * direction) > 0
        end
    end
end

end
