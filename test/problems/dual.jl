module TestDual

# Lemma 6.25 of Debauche, made constructive and checked on every lift: the dual
# norms of a certificate's node functions are a certificate on the dual graph
# for the transposed system in the dual template, at the same rate. The test
# also asserts Proposition 7.5 on the validity declarations -- a lift is valid
# for a template exactly when its dual is valid for the dual template -- and,
# wherever a lift is valid, that the rate it certifies is no worse.

import SetProg
using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

edgeset(g) = Set(
    (PCC.source(e), PCC.dest(e), collect(PCC.letters(PCC.label(g, e)))) for
    e in PCC.edges(g)
)

# The numbers a fitted node function is made of, whatever the template.
coefficients(V::SetProg.Sets.Ellipsoid) = V.Q
coefficients(V::SetProg.Sets.PolarPoint) = V.a
coefficients(V::SetProg.Sets.Intersection) = coefficients(V.set)
coefficients(V::SetProg.Sets.Polar) = coefficients(SetProg.polar(V))
coefficients(V::SetProg.Sets.Piecewise) = reduce(vcat, [s.a for s in V.sets])

# A positive system for the copositive pair, a general one for the quadratic
# template; both invertible, so the composition lifts are valid somewhere.
const POSITIVE = PCC.switched_system([
    [0.5 0.3 0.0; 0.1 0.4 0.2; 0.0 0.2 0.6],
    [0.3 0.0 0.4; 0.2 0.5 0.1; 0.3 0.1 0.2],
])
const GENERAL = PCC.switched_system([[0.8 0.3; -0.2 0.5], [0.4 -0.6; 0.5 0.3]])

const CASES = [
    (PCC.QuadraticTemplate(), GENERAL),
    (PCC.LinearCopositiveTemplate(), POSITIVE),
    (PCC.DualCopositiveTemplate(), POSITIVE),
]

const ONE = PCC.common_graph(2)
const TWO = PCC.de_bruijn(1, 2)

# Every lift, applied where it is defined: the four applied at edges at some of
# the edges of the two-node graph, the rest on one of the two seeds.
const STEPS = [
    ("out-splitting", PCC.OutSplitLift(), TWO, PCC.outgoing_edges(TWO, 1)),
    ("in-splitting", PCC.InSplitLift(), TWO, PCC.incoming_edges(TWO, 1)),
    ("forward product", PCC.ForwardProductLift(), TWO, PCC.outgoing_edges(TWO, 1)[1:1]),
    ("backward product", PCC.BackwardProductLift(), TWO, PCC.incoming_edges(TWO, 2)[1:1]),
    ("memory", PCC.PathDependentLift(1), ONE, nothing),
    ("product", PCC.ProductLift(2), ONE, nothing),
    ("composition", PCC.CompositionLift(1), ONE, nothing),
    ("backward composition", PCC.BackwardCompositionLift(1), ONE, nothing),
    ("min", PCC.MinLift(), TWO, nothing),
    ("max", PCC.MaxLift(), TWO, nothing),
    ("sum", PCC.SumLift(2), TWO, nothing),
]
apply(L::PCC.AbstractLift, base, ::Nothing) = PCC.graph(PCC.lift(L, base))
apply(L::PCC.AbstractLift, base, edge_list) = PCC.graph(PCC.lift(L, base, edge_list))

bound(template, g, problem) = PCC.jsr_bound(
    template,
    g,
    problem;
    optimizer = OPTIMIZER,
    rtol = 1e-4,
    initial_upper = 2.0,
)

const BASE_RATES = Dict(
    (template, g) => bound(template, g, PCC.StabilityProblem(system)).rate for
    (template, system) in CASES, g in (ONE, TWO)
)

@testset "the dual certificate on $name for $(nameof(typeof(template)))" for (
        name,
        step,
        base,
        edge_list,
    ) in STEPS,
    (template, system) in CASES

    g = apply(step, base, edge_list)
    problem = PCC.StabilityProblem(system)
    primal = bound(template, g, problem)
    @test PCC.is_feasible(primal)

    dualised = PCC.dual(primal)
    @test dualised isa PCC.StabilityCertificate
    @test PCC.is_feasible(dualised)
    @test dualised.rate == primal.rate
    @test PCC.status(dualised) == PCC.status(primal)
    @test PCC.template(dualised) == PCC.dual(template)
    @test edgeset(PCC.graph(dualised)) == edgeset(PCC.dual(g))
    @test PCC.state_matrices(PCC.problem(dualised).system) ==
          [collect(transpose(A)) for A in PCC.state_matrices(system)]
    @test length(PCC.functions(dualised)) == PCC.n_nodes(g)

    # Lemma 6.25: every reversed edge inequality holds for the dual norms,
    # read off the certificate without solving anything.
    @test all(>=(-1e-6), PCC.edge_slacks(dualised))

    # Duality is an involution, down to the node functions.
    back = PCC.dual(dualised)
    @test PCC.template(back) == template
    @test edgeset(PCC.graph(back)) == edgeset(g)
    @test all(
        isapprox(coefficients(V), coefficients(W); rtol = 1e-8) for
        (V, W) in zip(PCC.functions(back), PCC.functions(primal))
    )

    # Lemma 6.26: solving the dual problem afresh certifies the same rate.
    fresh = bound(PCC.dual(template), PCC.dual(g), PCC.dual(problem))
    @test isapprox(fresh.rate, primal.rate; rtol = 1e-3)

    # The common function of the dual certificate is a function.
    if !PCC.has_words(g)
        @test dualised(ones(size(first(PCC.state_matrices(system)), 1))) > 0
    end

    # A valid lift is no worse than the graph it was applied to -- on the
    # backward ones, the guarantee that rests on the dual construction.
    if PCC.is_valid(step, template, system)
        @test primal.rate <= BASE_RATES[(template, base)] * (1 + 1e-3)
    end
end

@testset "validity is the same question on the dual side (Debauche, Prop. 7.5)" begin
    for (_, L, _, _) in STEPS, (template, _) in CASES, system in (POSITIVE, GENERAL)
        @test PCC.is_valid(L, template, system) ==
              PCC.is_valid(PCC.dual(L), PCC.dual(template), PCC.dual(system))
    end

    # What crossing over adds: the sum lift is valid for the dual copositive
    # norms because their primal is closed under addition, which they are not.
    @test !PCC.is_closed_under(PCC.DualCopositiveTemplate(), PCC.Addition(), POSITIVE)
    @test PCC.is_valid(PCC.SumLift(2), PCC.DualCopositiveTemplate(), POSITIVE)

    # And Thm. 7.43, stated on the primal, is read on the dual through closure.
    @test PCC.is_valid(PCC.MinLift(), PCC.LinearCopositiveTemplate(), POSITIVE)
    @test PCC.is_valid(PCC.MaxLift(), PCC.DualCopositiveTemplate(), POSITIVE)
    @test !PCC.is_valid(PCC.MaxLift(), PCC.LinearCopositiveTemplate(), POSITIVE)
    @test !PCC.is_valid(PCC.MinLift(), PCC.DualCopositiveTemplate(), POSITIVE)

    # A template without a dual is decided by its own closures only.
    @test PCC.is_valid(
        PCC.SumLift(2),
        PCC.ParallelFacesPolyhedralTemplate(1, 2),
        GENERAL,
    ) == PCC.is_closed_under(
        PCC.ParallelFacesPolyhedralTemplate(1, 2),
        PCC.Addition(),
        GENERAL,
    )
end

@testset "an infeasible certificate dualises to an infeasible one" begin
    problem = PCC.StabilityProblem(POSITIVE)
    none = PCC.certify(
        PCC.LinearCopositiveTemplate(),
        ONE,
        problem;
        optimizer = OPTIMIZER,
        rate = 0.01,
    )
    @test !PCC.is_feasible(none)

    dualised = PCC.dual(none)
    @test !PCC.is_feasible(dualised)
    @test PCC.status(dualised) == PCC.status(none)
    @test isempty(PCC.functions(dualised))
    @test dualised.rate == none.rate
    @test PCC.template(dualised) == PCC.DualCopositiveTemplate()
end

@testset "a template without a dual says so" begin
    @test PCC.has_dual(PCC.QuadraticTemplate())
    @test PCC.has_dual(PCC.LinearCopositiveTemplate())
    @test PCC.has_dual(PCC.DualCopositiveTemplate())
    @test !PCC.has_dual(PCC.ParallelFacesPolyhedralTemplate(1, 2))

    @test_throws ArgumentError PCC.dual(PCC.ParallelFacesPolyhedralTemplate(1, 2))

    polyhedral =
        bound(PCC.ParallelFacesPolyhedralTemplate(1, 2), ONE, PCC.StabilityProblem(GENERAL))
    @test PCC.is_feasible(polyhedral)
    @test_throws ArgumentError PCC.dual(polyhedral)
end

end # module
