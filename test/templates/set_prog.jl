module TestSetProg

# The SetProg template lives in a package extension, so this file is the only
# one that loads SetProg.
#
# The anchors are the templates it overlaps with: an ellipsoid is
# `QuadraticTemplate`, a polynomial set is `SumOfSquaresTemplate`, and a
# polytope that is linear on the cones over the facets of a partition is
# `ConicPolyhedralTemplate` on the same cones. What it adds, the piecewise
# semi-ellipsoids, is checked against these and against the edge inequality.

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
# the facets of the octagon are the cones of `planar_conic_partition(1)`: its
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

@testset "the extension is what supplies the methods" begin
    @test Base.get_extension(PCC, :PathCompleteCertificatesSetProgExt) !== nothing
end

@testset "the degree is the one of the set variable" begin
    @test PCC.homogeneity_degree(PCC.SetProgTemplate(Ellipsoid(symmetric = true))) == 2
    @test PCC.homogeneity_degree(
        PCC.SetProgTemplate(PolySet(symmetric = true, degree = 6, variables = x)),
    ) == 6
    @test PCC.homogeneity_degree(
        PCC.SetProgTemplate(Polytope(symmetric = true, piecewise = SQUARE)),
    ) == 1
    mixed = PCC.SetProgTemplate([
        Ellipsoid(symmetric = true),
        PolySet(symmetric = true, degree = 4, variables = x),
    ])
    @test_throws ArgumentError PCC.homogeneity_degree(mixed)
end

# The one-node ellipsoid bound, shared by the tests below.
const ELLIPSOID = rate(PCC.SetProgTemplate(Ellipsoid(; symmetric = true)))

@testset "an ellipsoid reproduces the quadratic template" begin
    quadratic = rate(PCC.QuadraticTemplate())

    @test PCC.is_feasible(ELLIPSOID)
    @test abs(ELLIPSOID.rate - quadratic.rate) <= AGREE

    V = only(PCC.functions(ELLIPSOID))
    @test V isa PCC.SetProgFunction
    # V(cx) = c² V(x), and the normalization `V ≥ ‖x‖²`
    @test V([2.0, 3.0]) ≈ 4 * V([1.0, 1.5]) rtol = 1e-6
    @test V([1.0, 1.0]) >= 2 - 1e-6
    test_edges(ELLIPSOID, PCC.SetProgTemplate(Ellipsoid(symmetric = true)), MEMORYLESS)
end

@testset "a polynomial set reproduces the sum-of-squares template" begin
    sos = rate(PCC.SumOfSquaresTemplate(2, x))
    template = PCC.SetProgTemplate(PolySet(symmetric = true, degree = 4, variables = x))
    polyset = rate(template)

    @test PCC.is_feasible(polyset)
    @test abs(polyset.rate - sos.rate) <= AGREE
    test_edges(polyset, template, MEMORYLESS)
end

@testset "a piecewise polytope reproduces the conic polyhedral template" begin
    conic = rate(PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(1)]))
    template = PCC.SetProgTemplate(Polytope(symmetric = true, piecewise = OCTAGON))
    polytope = rate(template)

    @test PCC.is_feasible(polytope)
    @test abs(polytope.rate - conic.rate) <= AGREE
    test_edges(polytope, template, MEMORYLESS)
end

@testset "piecewise semi-ellipsoids" begin
    piecewise = Dict(
        name => rate(
            PCC.SetProgTemplate(Ellipsoid(symmetric = true, piecewise = partition)),
        ) for (name, partition) in [("square", SQUARE), ("octagon", OCTAGON)]
    )

    @testset "$name" for (name, partition) in [("square", SQUARE), ("octagon", OCTAGON)]
        template = PCC.SetProgTemplate(Ellipsoid(symmetric = true, piecewise = partition))
        certificate = piecewise[name]

        @test PCC.is_feasible(certificate)
        # An ellipsoid is a piecewise semi-ellipsoid whose pieces are equal
        @test certificate.rate <= ELLIPSOID.rate + AGREE
        @test certificate.rate >= LOWER_BOUND - 1e-4

        V = only(PCC.functions(certificate))
        @test V.set isa SetProg.Sets.Piecewise
        test_edges(certificate, template, MEMORYLESS)
    end

    @testset "more pieces, lower rate" begin
        @test piecewise["octagon"].rate < ELLIPSOID.rate - 1e-2
    end

    @testset "one partition per node" begin
        graph = PCC.de_bruijn(1, 2)
        template = PCC.SetProgTemplate([
            Ellipsoid(symmetric = true, piecewise = SQUARE),
            Ellipsoid(symmetric = true, piecewise = OCTAGON),
        ])
        certificate = rate(template, graph)

        @test PCC.is_feasible(certificate)
        @test certificate.rate >= LOWER_BOUND - 1e-4
        test_edges(certificate, template, graph)
    end
end

@testset "the template follows a lift" begin
    shared = PCC.SetProgTemplate(Ellipsoid(symmetric = true))
    @test PCC.reindex(shared, [1, 1, 1]) === shared

    square = Ellipsoid(symmetric = true, piecewise = SQUARE)
    octagon = Ellipsoid(symmetric = true, piecewise = OCTAGON)
    per_node = PCC.SetProgTemplate([square, octagon])

    # Each new node gets the variable of its origin.
    lifted = PCC.reindex(per_node, [2, 1, 2])
    @test lifted.variables[1] === octagon
    @test lifted.variables[2] === square
    @test lifted.variables[3] === octagon
    @test !lifted.shared

    # Merging nodes is fine when they carry the same variable, not otherwise.
    @test only(PCC.reindex(PCC.SetProgTemplate([square, square]), [[1, 2]]).variables) ===
          square
    @test_throws ArgumentError PCC.reindex(per_node, [[1, 2]])
end

@testset "closed under addition when the nodes share the variable" begin
    system = PROBLEM.system
    shared = PCC.SetProgTemplate(Ellipsoid(symmetric = true))
    @test PCC.is_closed_under(shared, PCC.Addition(), system)
    @test PCC.is_valid(PCC.SumLift(2), shared, system)

    octagon = Ellipsoid(symmetric = true, piecewise = OCTAGON)
    same = PCC.SetProgTemplate([octagon, octagon])
    @test PCC.is_closed_under(same, PCC.Addition(), system)

    mixed = PCC.SetProgTemplate([Ellipsoid(symmetric = true, piecewise = SQUARE), octagon])
    @test !PCC.is_closed_under(mixed, PCC.Addition(), system)
    @test !PCC.is_valid(PCC.SumLift(2), mixed, system)
    @test !PCC.is_closed_under(shared, PCC.Maximum(), system)
end

@testset "what the template does not support" begin
    @test_throws ArgumentError rate(PCC.SetProgTemplate(Ellipsoid(dimension = 2)))
    @test_throws ArgumentError rate(
        PCC.SetProgTemplate(PolySet(symmetric = true, degree = 4)),
    )
    @test_throws ArgumentError rate(
        PCC.SetProgTemplate(Polytope(symmetric = true, dimension = 2)),
    )
    @polyvar y[1:3]
    @test_throws ArgumentError rate(
        PCC.SetProgTemplate(PolySet(symmetric = true, degree = 4, variables = y)),
    )
    @test_throws ArgumentError rate(
        PCC.SetProgTemplate([Ellipsoid(symmetric = true)]),
        PCC.de_bruijn(1, 2),
    )

    model = JuMP.Model()
    template = PCC.SetProgTemplate(Ellipsoid(symmetric = true))
    S = PCC.add_function_variables!(model, template, 2, 1)
    @test_throws ArgumentError PCC.add_decrease!(model, template, S, S, A[1]; margin = 1)
    @test_throws ArgumentError PCC.add_decrease!(
        model,
        template,
        S,
        S,
        A[1];
        scale = JuMP.@variable(model),
    )
end

end
