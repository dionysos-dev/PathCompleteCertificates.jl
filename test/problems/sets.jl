module TestSetFamilies

# Native SetProg families for stability.

using Test
using LinearAlgebra
using HybridSystems
using SetProg
using SumOfSquares, DynamicPolynomials
import PathCompleteCertificates as PCC
import Clarabel
import HiGHS

const OPTIMIZER = Clarabel.Optimizer

# A rotation and a shear: no quadratic attains the joint spectral radius.
const A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))
# Every product of modes bounds the joint spectral radius from below.
const LOWER_BOUND = maximum(Ai -> maximum(abs, eigvals(Ai)), A)

const MEMORYLESS = GraphAutomaton(1)
add_transition!(MEMORYLESS, 1, 1, 1)
add_transition!(MEMORYLESS, 1, 1, 2)

# The Polyhedra library needs an LP solver to detect the linearity of the
# pieces, and SetProg runs many small programs on it at every solve: a simplex
# solver keeps them cheap, where Clarabel would triple the time of each solve.
const LIB = Polyhedra.DefaultLibrary{Float64}(
    JuMP.optimizer_with_attributes(HiGHS.Optimizer, JuMP.MOI.Silent() => true),
)

# Partitions with exact facets, see the warning in the docstring. The cones over
# the facets of the octagon are the cones of `PCC.planar_conic_partition(1)`: its
# vertices are on the rays ±(1, 0), ±(1, 1), ±(0, 1) and ±(-1, 1).
const SQUARE = polyhedron(
    hrep([
        HalfSpace([1.0, 0.0], 1.0),
        HalfSpace([-1.0, 0.0], 1.0),
        HalfSpace([0.0, 1.0], 1.0),
        HalfSpace([0.0, -1.0], 1.0),
    ]),
    LIB,
)
const OCTAGON = polyhedron(
    hrep([
        HalfSpace(a, 6.0) for a in [
            [2.0, 1.0],
            [1.0, 2.0],
            [-1.0, 2.0],
            [-2.0, 1.0],
            [-2.0, -1.0],
            [-1.0, -2.0],
            [1.0, -2.0],
            [2.0, -1.0],
        ]
    ]),
    LIB,
)

@polyvar x[1:2]

# Every bound is bisected to `rtol`, so two of them agree to about twice that.
rate(template, graph = MEMORYLESS) =
    PCC.jsr_bound(template, graph, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)
const AGREE = 2e-3

# The edge inequality `V_dst(A x) ≤ γᵈ V_src(x)`, sampled on the circle.
function test_edges(certificate, template, graph)
    V = PCC.functions(certificate)
    scale = certificate.rate^PCC.homogeneity_degree(template)

    for edge in PCC.edges(graph), θ in range(0, 2π; length = 97)
        point = [cos(θ), sin(θ)]
        src = V[PCC.source(edge)]
        dst = V[PCC.dest(edge)]
        @test scale * src(point) - dst(A[PCC.label(graph, edge)] * point) >= -1e-5
    end
end

@testset "SetProg is a direct dependency" begin
    @test PCC.SetProg === SetProg
    @test Base.get_extension(PCC, :PathCompleteCertificatesSetProgExt) === nothing
end

@testset "the degree is the one of the set variable" begin
    @test PCC.homogeneity_degree(Ellipsoid(symmetric = true)) == 2
    @test PCC.homogeneity_degree(PolySet(symmetric = true, degree = 6, variables = x)) == 6
    @test PCC.homogeneity_degree(Polytope(symmetric = true, piecewise = SQUARE)) == 1
    mixed =
        [Ellipsoid(symmetric = true), PolySet(symmetric = true, degree = 4, variables = x)]
    @test_throws ArgumentError PCC.homogeneity_degree(mixed)
end

# The one-node ellipsoid bound, shared by the tests below.
const ELLIPSOID = rate(Ellipsoid(; symmetric = true))

@testset "an ellipsoid fits a normalized quadratic gauge" begin
    @test PCC.is_feasible(ELLIPSOID)
    @test ELLIPSOID.rate >= LOWER_BOUND - 1e-4

    V = only(PCC.functions(ELLIPSOID))
    @test V isa SetProg.Sets.Ellipsoid
    # V(cx) = c² V(x), and the normalization `V ≥ ‖x‖²`
    @test V([2.0, 3.0]) ≈ 4 * V([1.0, 1.5]) rtol = 1e-6
    @test V([1.0, 1.0]) >= 2 - 1e-6
    test_edges(ELLIPSOID, Ellipsoid(symmetric = true), MEMORYLESS)
end

@testset "a polynomial set fits a sum-of-squares gauge" begin
    template = PolySet(symmetric = true, degree = 4, variables = x)
    polyset = rate(template)

    @test PCC.is_feasible(polyset)
    @test polyset.rate >= LOWER_BOUND - 1e-4
    @test polyset.rate <= ELLIPSOID.rate + AGREE
    test_edges(polyset, template, MEMORYLESS)
end

@testset "a piecewise polytope reproduces the conic polyhedral template" begin
    conic = rate(PCC.ConicPolytope.([PCC.planar_conic_partition(1)]))
    template = Polytope(symmetric = true, piecewise = OCTAGON)
    polytope = rate(template)

    @test PCC.is_feasible(polytope)
    @test abs(polytope.rate - conic.rate) <= AGREE
    test_edges(polytope, template, MEMORYLESS)
end

@testset "piecewise semi-ellipsoids" begin
    piecewise = Dict(
        name => rate(Ellipsoid(symmetric = true, piecewise = partition)) for
        (name, partition) in [("square", SQUARE), ("octagon", OCTAGON)]
    )

    @testset "$name" for (name, partition) in [("square", SQUARE), ("octagon", OCTAGON)]
        template = Ellipsoid(symmetric = true, piecewise = partition)
        certificate = piecewise[name]

        @test PCC.is_feasible(certificate)
        # An ellipsoid is a piecewise semi-ellipsoid whose pieces are equal
        @test certificate.rate <= ELLIPSOID.rate + AGREE
        @test certificate.rate >= LOWER_BOUND - 1e-4

        V = only(PCC.functions(certificate))
        @test V isa SetProg.Sets.Piecewise
        test_edges(certificate, template, MEMORYLESS)
    end

    @testset "more pieces, lower rate" begin
        @test piecewise["octagon"].rate < ELLIPSOID.rate - 1e-2
    end

    @testset "one partition per node" begin
        graph = PCC.de_bruijn(1, 2)
        template = [
            Ellipsoid(symmetric = true, piecewise = SQUARE),
            Ellipsoid(symmetric = true, piecewise = OCTAGON),
        ]
        certificate = rate(template, graph)

        @test PCC.is_feasible(certificate)
        @test certificate.rate >= LOWER_BOUND - 1e-4
        test_edges(certificate, template, graph)
    end
end

@testset "the template follows a lift" begin
    shared = Ellipsoid(symmetric = true)
    @test PCC.reindex(shared, [1, 1, 1]) === shared

    square = Ellipsoid(symmetric = true, piecewise = SQUARE)
    octagon = Ellipsoid(symmetric = true, piecewise = OCTAGON)
    per_node = [square, octagon]

    # Each new node gets the variable of its origin.
    lifted = PCC.reindex(per_node, [2, 1, 2])
    @test lifted[1] === octagon
    @test lifted[2] === square
    @test lifted[3] === octagon

    # Merging nodes is fine when they carry the same variable, not otherwise.
    @test only(PCC.reindex([square, square], [[1, 2]])) === square
    @test_throws ArgumentError PCC.reindex(per_node, [[1, 2]])
end

@testset "closed under addition when the nodes share the variable" begin
    system = PROBLEM.system
    shared = Ellipsoid(symmetric = true)
    @test PCC.is_closed_under(shared, PCC.Addition(), system)
    @test PCC.is_valid(PCC.SumLift(2), shared, system)

    octagon = Ellipsoid(symmetric = true, piecewise = OCTAGON)
    same = [octagon, octagon]
    @test PCC.is_closed_under(same, PCC.Addition(), system)

    mixed = [Ellipsoid(symmetric = true, piecewise = SQUARE), octagon]
    @test !PCC.is_closed_under(mixed, PCC.Addition(), system)
    @test !PCC.is_valid(PCC.SumLift(2), mixed, system)
    @test !PCC.is_closed_under(shared, PCC.Maximum(), system)
end

@testset "family validation and zero rate" begin
    @test_throws ArgumentError rate(Ellipsoid(dimension = 2))
    @test_throws ArgumentError rate(Polytope(symmetric = true, dimension = 2))
    @polyvar y[1:3]
    @test_throws DimensionMismatch rate(
        PolySet(symmetric = true, degree = 4, variables = y),
    )
    @test_throws ArgumentError rate([Ellipsoid(symmetric = true)], PCC.de_bruijn(1, 2))

    model = JuMP.Model()
    template = Ellipsoid(symmetric = true)
    S = PCC.add_function_variables!(model, template, 2, 1)
    PCC.add_normalization!(model, S.set, S)
    PCC.add_decrease!(model, template, S, S, A[1]; scale = 0)
    @test JuMP.num_constraints(model; count_variable_in_set_constraints = false) > 0
end

@testset "inferred polynomial coordinates are shared by the nodes" begin
    diagonal = PCC.StabilityProblem(PCC.switched_system([[0.5 0.0; 0.0 0.25]]))
    graph = PCC.de_bruijn(1, 1)
    family = PolySet(symmetric = true, degree = 4)
    certificate = PCC.certify(family, graph, diagonal; optimizer = OPTIMIZER, rate = 0.6)
    @test PCC.is_feasible(certificate)
    @test only(PCC.functions(certificate))([1.0, 1.0]) >= 4 - 1e-5
    @polyvar y[1:2]
    different = [PolySet(symmetric = true, degree = 4, variables = z) for z in (x, y)]
    @test_throws ArgumentError PCC.optimization_model(
        different,
        PCC.de_bruijn(1, 2),
        PROBLEM;
        optimizer = OPTIMIZER,
    )
    models = PCC.optimization_model(
        [family, family],
        PCC.de_bruijn(1, 2),
        PROBLEM;
        optimizer = OPTIMIZER,
    )
    @test models[:stability_V][1].set.variables == models[:stability_V][2].set.variables
end

@testset "native per-node polyhedral families and duals" begin
    system = PCC.switched_system([[0.5 0.0; 0.0 0.25], [0.25 0.0; 0.0 0.5]])
    problem = PCC.StabilityProblem(system)
    graph = PCC.de_bruijn(1, 2)
    families =
        [PCC.Parallelotope([1.0 0.0; 0.0 1.0]), PCC.Parallelotope([2.0 0.0; 0.0 1.0])]
    certificate =
        PCC.certify(families, graph, problem; optimizer = HiGHS.Optimizer, rate = 0.8)
    @test PCC.is_feasible(certificate)
    @test all(>=(-1e-6), PCC.edge_slacks(certificate))
    @test !PCC.is_closed_under(families, PCC.Maximum(), system)
    @test PCC.is_closed_under([families[1], families[1]], PCC.Maximum(), system)
    boxes = [PCC.PositiveBox(min_weight = 2), PCC.PositiveBox(min_weight = 3)]
    certificate =
        PCC.certify(boxes, graph, problem; optimizer = HiGHS.Optimizer, rate = 0.8)
    @test PCC.has_dual(boxes)
    @test PCC.dual(PCC.dual(boxes)) == boxes
    @test all(>=(-1e-6), PCC.edge_slacks(PCC.dual(certificate)))
    @test_throws ArgumentError PCC.dual(families)
    @test !PCC.is_closed_under(
        Ellipsoid(symmetric = true, piecewise = SQUARE),
        PCC.Composition(),
        PROBLEM.system,
    )
    @test !PCC.is_closed_under(
        Ellipsoid(symmetric = true, piecewise = SQUARE),
        PCC.InverseComposition(),
        PROBLEM.system,
    )
end

@testset "the native gauge primitives also work directly" begin
    family = PCC.PositiveBox(min_weight = 2)
    model = JuMP.Model(HiGHS.Optimizer)
    JuMP.set_silent(model)
    S = PCC.add_function_variables!(model, family, 2, 1)
    PCC.add_normalization!(model, S.set, S)
    A = [0.5 0.0; 0.0 0.25]
    PCC.add_decrease!(model, family, S, S, A; scale = 0.6)
    JuMP.optimize!(model)
    fitted = PCC.solution_value(family, S)
    @test fitted([2.0, 0.0]) <= 1 + 1e-6
    @test fitted(A * [2.0, 1.0]) <= 0.6 * fitted([2.0, 1.0]) + 1e-6
    system = PCC.switched_system([A])
    @test PCC.is_closed_under(PCC.PositiveSimplex(), PCC.Composition(), system)
    @test PCC.is_closed_under(PCC.PositiveSimplex(), PCC.InverseComposition(), system)
end

@testset "compatibility constructors return native families" begin
    @test PCC.PositiveBox() isa SetProg.Polytope
    @test PCC.PositiveSimplex() isa SetProg.Polytope
    @test PCC.Parallelotope() isa SetProg.Polytope
    @test PCC.ConicPolytope(PCC.planar_conic_partition(1)) isa SetProg.Polytope
    @test PCC.LinearCopositiveTemplate() == PCC.PositiveSimplex()
    @test PCC.DualCopositiveTemplate() == PCC.PositiveBox()
    @test length(PCC.ParallelFacesPolyhedralTemplate(2, 2)) == 2
    @test length(PCC.ParallelFacesPolyhedralTemplate([[1.0 0.0; 0.0 1.0]])) == 1
    @test length(PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(1)])) == 1
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(0, 2)
    @test_throws ArgumentError PCC.ParallelFacesPolyhedralTemplate(Matrix{Float64}[])
    @test_throws ArgumentError PCC.planar_conic_partition(0)
    @test PCC.PositiveBox([2.0, 3.0])([1.0, 1.0]) ≈ 0.5
    @test PCC.PositiveSimplex([2.0, 3.0])([1.0, 1.0]) ≈ 5
end

end
