module TestCompare

# The fixture is the repeatability capsule of Debauche, Della Rossa & Jungers,
# HSCC 2023 (Code Ocean 0480330): five graphs on two modes, one positive
# system, and the rates its main script prints.

import SetProg
using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

function graph(edges, n)
    g = GraphAutomaton(n)
    for (a, b, l) in edges
        add_transition!(g, a, b, l)
    end
    return g
end

const G0 = graph([(1, 1, 1), (1, 1, 2)], 1)
const G1 = graph(
    [
        (1, 2, 1),
        (2, 1, 1),
        (1, 3, 1),
        (3, 1, 2),
        (1, 4, 2),
        (4, 1, 1),
        (1, 5, 2),
        (5, 1, 2),
    ],
    5,
)
const G2 = graph(
    [
        (1, 3, 2),
        (1, 4, 2),
        (2, 1, 1),
        (2, 2, 1),
        (3, 3, 2),
        (3, 4, 2),
        (4, 2, 1),
        (4, 1, 1),
    ],
    4,
)
const G3 = graph(
    [
        (1, 2, 1),
        (1, 5, 2),
        (1, 4, 1),
        (2, 3, 1),
        (2, 4, 2),
        (3, 4, 1),
        (3, 4, 2),
        (4, 3, 2),
        (4, 2, 2),
        (4, 5, 1),
        (5, 1, 1),
        (5, 1, 2),
    ],
    5,
)
const G4 = graph(
    [
        (1, 2, 1),
        (2, 4, 1),
        (3, 2, 1),
        (4, 3, 1),
        (4, 5, 1),
        (5, 1, 1),
        (1, 4, 2),
        (1, 3, 2),
        (2, 1, 2),
        (3, 2, 2),
        (4, 5, 2),
        (5, 1, 2),
    ],
    5,
)

const A_STAR = [[1.5519 0.44737; 7.6412 7.4716], [0.47501 9.1755; 1.8955 0.18502]]
const SYSTEM = PCC.switched_system(A_STAR)
const PROBLEM = PCC.StabilityProblem(SYSTEM)

const QUADRATIC = SetProg.Ellipsoid(; symmetric = true)
const COPOSITIVE = PCC.PositiveSimplex()
const DUAL_COPOSITIVE = PCC.PositiveBox()
const TEMPLATES = (QUADRATIC, COPOSITIVE, DUAL_COPOSITIVE)

found(comparison) = Dict(PCC.simulations(comparison))

@testset "the five graphs read both modes" begin
    for g in (G0, G1, G2, G3, G4)
        @test PCC.is_path_complete(g, 1:2)
    end
    @test PCC.is_complete(G4, 1:2) && PCC.is_co_complete(G4, 1:2)
    @test PCC.is_complete(G3, 1:2) && PCC.is_co_complete(G3, 1:2)
    @test !PCC.is_complete(G1, 1:2) && !PCC.is_co_complete(G1, 1:2)
end

@testset "every lift preserves path-completeness" begin
    for g in (G0, G1, G2, G4),
        L in (
            PCC.IdentityLift(),
            PCC.MinLift(),
            PCC.MaxLift(),
            PCC.SumLift(2),
            PCC.CompositionLift(1),
            PCC.BackwardCompositionLift(1),
        )

        @test PCC.is_path_complete(PCC.graph(PCC.lift(L, g)), 1:2)
    end
end

@testset "G_2 is no worse than G_1 for addition-closed templates, by the sum lift" begin
    c = PCC.compare(G1, G2; templates = TEMPLATES, system = SYSTEM, optimizer = OPTIMIZER)
    simulations = found(c)

    @test first(PCC.lifts(c)) == PCC.IdentityLift()
    @test PCC.SumLift() in PCC.lifts(c)
    @test !haskey(simulations, PCC.IdentityLift())

    # Whenever a sum lift simulates, so do the min and max lifts (Debauche,
    # Cor. 7.80).
    @test haskey(simulations, PCC.MinLift())
    @test haskey(simulations, PCC.MaxLift())

    C = simulations[PCC.SumLift()]
    @test size(C) == (4, 5)
    @test all(>=(0), C)
    @test all(>=(1), sum(C; dims = 2))

    # The quadratic and copositive norms add; the dual copositive norms are
    # proved through their dual (Debauche, Prop. 7.5).
    @test Set(PCC.templates(c)) == Set(TEMPLATES)
end

@testset "G_4 against G_0: the template decides" begin
    c = PCC.compare(G4, G0; templates = TEMPLATES, system = SYSTEM, optimizer = OPTIMIZER)
    simulations = found(c)

    # Complete and co-complete: both subset lifts simulate G_0 by the full
    # node set; no sum lift does, and the one-node graph has no map into G_4.
    @test simulations[PCC.MinLift()] == [[1, 2, 3, 4, 5]]
    @test simulations[PCC.MaxLift()] == [[1, 2, 3, 4, 5]]
    @test !haskey(simulations, PCC.SumLift())
    @test !haskey(simulations, PCC.IdentityLift())
    @test Set(PCC.templates(c)) == Set([COPOSITIVE, DUAL_COPOSITIVE])

    # The other way round the identity map settles it for every template, and
    # nothing else is tried.
    back =
        PCC.compare(G0, G4; templates = TEMPLATES, system = SYSTEM, optimizer = OPTIMIZER)
    @test PCC.lifts(back) == [PCC.IdentityLift()]
    @test only(PCC.simulations(back)).second == fill(1, 5)
    @test Set(PCC.templates(back)) == Set(TEMPLATES)

    # A co-complete De Bruijn graph collapses for max-closed templates only.
    co = PCC.dual(PCC.de_bruijn(2, 2))
    c = PCC.compare(co, G0; templates = TEMPLATES, system = SYSTEM)
    @test haskey(found(c), PCC.MaxLift())
    @test !haskey(found(c), PCC.MinLift())
    @test PCC.templates(c) == [DUAL_COPOSITIVE]
end

@testset "G_3 buys nothing for addition-closed templates; G_4 does" begin
    c3 = PCC.compare(
        G3,
        G0;
        templates = (QUADRATIC,),
        system = SYSTEM,
        optimizer = OPTIMIZER,
    )
    @test PCC.templates(c3) == [QUADRATIC]
    @test size(found(c3)[PCC.SumLift()]) == (1, 5)

    c4 = PCC.compare(
        G4,
        G0;
        templates = (QUADRATIC,),
        system = SYSTEM,
        optimizer = OPTIMIZER,
    )
    @test isempty(PCC.templates(c4))
end

@testset "what compare needs, and what it skips" begin
    c = PCC.compare(G1, G2; system = SYSTEM)
    @test !any(L -> L isa PCC.SumLift, PCC.lifts(c))
    @test isempty(PCC.templates(c))

    c = PCC.compare(G1, G2; lifts = (PCC.SumLift(2),))
    @test PCC.lifts(c) == [PCC.SumLift(2)]
    @test all(m -> 1 in m, only(PCC.simulations(c)).second)

    @test_throws ArgumentError PCC.compare(G1, G2; templates = (QUADRATIC,))
    words = PCC.graph(PCC.lift(PCC.ProductLift(2), G1))
    @test_throws ArgumentError PCC.compare(words, G2)

    # A word graph whose words are single modes is compared as the plain graph.
    single_modes = PCC.WordGraph(1)
    PCC.add_edge!(single_modes, 1, 1, [1])
    PCC.add_edge!(single_modes, 1, 1, [2])
    @test PCC.simulations(PCC.compare(single_modes, G0)) ==
          PCC.simulations(PCC.compare(G0, G0))
end

@testset "the ten rates of the capsule" begin
    expected_quadratic = [9.5868, 9.0161, 8.6881, 9.5868, 9.4886]
    expected_copositive = [9.2696, 9.1712, 8.7019, 9.2696, 9.2696]

    for (k, g) in enumerate((G0, G1, G2, G3, G4))
        q = PCC.jsr_bound(
            QUADRATIC,
            g,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        c = PCC.jsr_bound(
            COPOSITIVE,
            g,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        @test isapprox(q.rate, expected_quadratic[k]; atol = 2e-4)
        @test isapprox(c.rate, expected_copositive[k]; atol = 2e-4)
    end

    # The dual template on the dual problem certifies the same rates as the
    # primal on the original (Debauche, Lemma 6.25).
    dual_problem = PCC.StabilityProblem(PCC.dual(SYSTEM))
    for g in (G1, G4)
        primal = PCC.jsr_bound(
            COPOSITIVE,
            g,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        dualised = PCC.jsr_bound(
            DUAL_COPOSITIVE,
            PCC.dual(g),
            dual_problem;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        @test isapprox(primal.rate, dualised.rate; rtol = 1e-3)
    end
end

end # module
