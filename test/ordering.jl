module TestOrdering

# The fixture is the repeatability capsule of Debauche, Della Rossa & Jungers,
# HSCC 2023 (Code Ocean 0480330): five graphs on two modes, one positive
# system, and every relation, matrix and rate its main script prints.

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

@testset "the five graphs read both modes" begin
    for g in (G0, G1, G2, G3, G4)
        @test PCC.is_path_complete(g, 1:2)
    end
    @test PCC.is_complete(G4, 1:2) && PCC.is_co_complete(G4, 1:2)
    @test PCC.is_complete(G3, 1:2) && PCC.is_co_complete(G3, 1:2)
    @test !PCC.is_complete(G1, 1:2) && !PCC.is_co_complete(G1, 1:2)
end

@testset "Example 1: G_1 does not simulate G_2, its 2-sum lift does" begin
    @test PCC.simulation(G1, G2) === nothing

    lifted = PCC.SumLift(2)(G1)
    R = PCC.simulation(PCC.graph(lifted), G2)
    @test R !== nothing

    # The capsule's relation: a₂ ↦ {a₁,c₁}, b₂ ↦ {a₁,b₁}, c₂ ↦ {a₁,e₁}, d₂ ↦ {a₁,d₁}.
    # Any simulation is accepted by the theorem; this one is what the capsule
    # printed and is checked to be one of the valid answers.
    multisets = [PCC.origins(lifted)[r] for r in R]
    @test all(m -> 1 in m, multisets)
    capsule = [[1, 3], [1, 2], [1, 5], [1, 4]]
    index = Dict(m => k for (k, m) in enumerate(PCC.origins(lifted)))
    @test all(haskey(index, m) for m in capsule)
    edges_lift = Set(
        (PCC.source(e), PCC.dest(e), PCC.label(PCC.graph(lifted), e)) for
        e in PCC.edges(PCC.graph(lifted))
    )
    for e in PCC.edges(G2)
        @test (
            index[capsule[PCC.source(e)]],
            index[capsule[PCC.dest(e)]],
            PCC.label(G2, e),
        ) in edges_lift
    end
end

@testset "Example 2: the integer matrices of the LP" begin
    C12 = PCC.conic_witness(G1, G2; optimizer = OPTIMIZER)
    @test C12 !== nothing
    @test size(C12) == (4, 5)
    @test all(>=(0), C12)
    @test all(>=(1), sum(C12; dims = 2))

    C30 = PCC.conic_witness(G3, G0; optimizer = OPTIMIZER)
    @test C30 !== nothing
    @test size(C30) == (1, 5)
    @test all(>=(1), C30)

    # The LP is complete: no solution between G_4 and G_0, as the capsule finds.
    @test PCC.conic_witness(G4, G0; optimizer = OPTIMIZER) === nothing

    # Any graph dominates itself through the identity.
    @test PCC.conic_witness(G2, G2; optimizer = OPTIMIZER) !== nothing
end

@testset "the numerical example: min and max lifts of G_4 simulate G_0" begin
    @test PCC.simulation_relation(G4, G0) !== nothing
    @test PCC.simulation_relation(PCC.dual(G4), PCC.dual(G0)) !== nothing

    # The relation is what the explicit lift says, on small graphs.
    minlift = PCC.MinLift()(G4)
    @test PCC.simulation(PCC.graph(minlift), G0) !== nothing
    maxlift = PCC.MaxLift()(G4)
    @test PCC.simulation(PCC.graph(maxlift), G0) !== nothing

    # The greatest relation for (G_4, G_0) is the full node set, and the full
    # set is a max-lift witness because G_4 is co-complete; the capsule's
    # printed {a,b,d,e} is a min-lift witness only.
    @test PCC.simulation_relation(G4, G0) == [[1, 2, 3, 4, 5]]

    # G_1 and G_2 are not min-simulated by G_0, nor is G_0 by them.
    @test PCC.simulation_relation(G1, G0) === nothing
    @test PCC.simulation_relation(G2, G0) === nothing
end

@testset "closed induced subgraphs predict the collapse" begin
    @test PCC.closed_subgraph(G4, 1:2) == [1, 2, 3, 4, 5]
    @test PCC.closed_subgraph(G4, 1:2; direction = :in) == [1, 2, 3, 4, 5]
    @test PCC.closed_subgraph(G3, 1:2) == [1, 2, 3, 4, 5]
    @test isempty(PCC.closed_subgraph(G1, 1:2))
    @test isempty(PCC.closed_subgraph(G2, 1:2))
    @test isempty(PCC.closed_subgraph(G2, 1:2; direction = :in))

    co = PCC.de_bruijn(2, 2; orientation = :co_complete)
    @test isempty(PCC.closed_subgraph(co, 1:2))
    @test PCC.closed_subgraph(co, 1:2; direction = :in) == [1, 2, 3, 4]

    @test_throws ArgumentError PCC.closed_subgraph(G4, 1:2; direction = :sideways)
end

@testset "order_witness reads the template's closures" begin
    quadratic = PCC.QuadraticTemplate()
    copositive = PCC.LinearCopositiveTemplate()
    dual_copositive = PCC.DualCopositiveTemplate()

    # Quadratic: closed under addition, so the LP decides. G_2 is no worse
    # than G_1, with a matrix; G_0 is not no-worse than G_4.
    w = PCC.order_witness(
        G1,
        G2;
        template = quadratic,
        system = SYSTEM,
        optimizer = OPTIMIZER,
    )
    @test w !== nothing && w.kind == :addition
    @test PCC.is_no_worse(
        G2,
        G1;
        template = quadratic,
        system = SYSTEM,
        optimizer = OPTIMIZER,
    )
    @test !PCC.is_no_worse(
        G0,
        G4;
        template = quadratic,
        system = SYSTEM,
        optimizer = OPTIMIZER,
    )
    @test_throws ArgumentError PCC.order_witness(
        G1,
        G2;
        template = quadratic,
        system = SYSTEM,
    )

    # Dual copositive norms are max-closed: G_0 is no worse than G_4 by the
    # relation on the duals. Primal copositive norms are addition-closed and,
    # on a positive system, valid for the min lift by the override.
    w = PCC.order_witness(G4, G0; template = dual_copositive, system = SYSTEM)
    @test w !== nothing && w.kind == :maximum
    @test PCC.is_valid(PCC.MinLift(), copositive, SYSTEM)
    @test !PCC.is_closed_under(copositive, PCC.Minimum(), SYSTEM)

    # Template-free: G_4 simulates G_0? A map from G_0's node to a node of G_4
    # with both loops: none has both self-loops.
    @test PCC.simulation(G4, G0) === nothing
    w = PCC.order_witness(
        G0,
        G4;
        template = quadratic,
        system = SYSTEM,
        optimizer = OPTIMIZER,
    )
    @test w !== nothing && w.kind == :simulation
end

@testset "simplify collapses what the closures allow" begin
    @test PCC.n_nodes(
        PCC.simplify(G4; template = PCC.DualCopositiveTemplate(), system = SYSTEM),
    ) == 1
    @test PCC.simplify(G1; template = PCC.DualCopositiveTemplate(), system = SYSTEM) === G1
    @test PCC.simplify(G4; template = PCC.QuadraticTemplate(), system = SYSTEM) === G4
end

@testset "the ten rates of the capsule" begin
    expected_quadratic = [9.5868, 9.0161, 8.6881, 9.5868, 9.4886]
    expected_copositive = [9.2696, 9.1712, 8.7019, 9.2696, 9.2696]

    for (k, g) in enumerate((G0, G1, G2, G3, G4))
        q = PCC.jsr_bound(
            PCC.QuadraticTemplate(),
            g,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        c = PCC.jsr_bound(
            PCC.LinearCopositiveTemplate(),
            g,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        @test isapprox(q.rate, expected_quadratic[k]; atol = 2e-4)
        @test isapprox(c.rate, expected_copositive[k]; atol = 2e-4)
    end

    # And the dual template on the dual problem certifies the same rates as the
    # primal on the original (Debauche, Lemma 6.25).
    dual_problem = PCC.StabilityProblem(PCC.dual(SYSTEM))
    for g in (G1, G4)
        primal = PCC.jsr_bound(
            PCC.LinearCopositiveTemplate(),
            g,
            PROBLEM;
            optimizer = OPTIMIZER,
            rtol = 1e-6,
            initial_upper = 100.0,
        )
        dualised = PCC.jsr_bound(
            PCC.DualCopositiveTemplate(),
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
