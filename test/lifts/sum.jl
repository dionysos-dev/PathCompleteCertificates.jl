module TestLiftSum

# The sum lift against the HSCC 2023 capsule of Debauche, Della Rossa &
# Jungers: the 2-sum lift of G_1 simulates G_2 (Example 1), and the linear
# program decides the sum lift over every size (Example 2).

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel

const OPTIMIZER = Clarabel.Optimizer

edgeset(g) = Set((PCC.source(e), PCC.dest(e), PCC.label(g, e)) for e in PCC.edges(g))

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

@testset "the T-sum lift by perfect matching" begin
    g = PCC.de_bruijn(1, 2)
    lifted = PCC.lift(PCC.SumLift(2), g)
    s = PCC.graph(lifted)

    @test PCC.origins(lifted) == [[1, 1], [1, 2], [2, 2]]
    @test PCC.is_path_complete(s, 1:2)
    @test PCC.requirements(PCC.SumLift(2)) == (PCC.Addition(),)
    @test PCC.requirements(PCC.SumLift()) == (PCC.Addition(),)

    # {1,1} → {1,1} under 1 uses the loop (1,1,1) twice (Prop. 7.10); {1,2} →
    # {1,2} under 1 has no matching; {1,1} → {2,2} under 2 uses (1,2,2) twice.
    @test (1, 1, 1) in edgeset(s)
    @test !((2, 2, 1) in edgeset(s))
    @test (1, 3, 2) in edgeset(s)

    # Self-dual (Debauche, Prop. 7.13).
    @test edgeset(PCC.dual(s)) == edgeset(PCC.graph(PCC.lift(PCC.SumLift(2), PCC.dual(g))))
    @test_throws ArgumentError PCC.SumLift(0)

    # The guard is on the lifted graph: eight nodes have 6435 multisets of eight.
    @test_throws ArgumentError PCC.lift(PCC.SumLift(8), PCC.de_bruijn(3, 2))

    # The sum lift over every size is not a graph.
    @test_throws ArgumentError PCC.lift(PCC.SumLift(), g)
end

@testset "Example 1: G_1 does not simulate G_2, its 2-sum lift does" begin
    @test PCC.simulation(PCC.IdentityLift(), G1, G2) === nothing

    multisets = PCC.simulation(PCC.SumLift(2), G1, G2)
    @test multisets !== nothing
    @test all(m -> 1 in m, multisets)

    # The capsule's relation is one of the valid answers: checked as a map
    # into the explicit lift.
    lifted = PCC.lift(PCC.SumLift(2), G1)
    index = Dict(m => k for (k, m) in enumerate(PCC.origins(lifted)))
    capsule = [[1, 3], [1, 2], [1, 5], [1, 4]]
    lifted_edges = edgeset(PCC.graph(lifted))
    for e in PCC.edges(G2)
        @test (
            index[capsule[PCC.source(e)]],
            index[capsule[PCC.dest(e)]],
            PCC.label(G2, e),
        ) in lifted_edges
    end
end

@testset "Example 2: the linear program and its integer matrices" begin
    C12 = PCC.simulation(PCC.SumLift(), G1, G2; optimizer = OPTIMIZER)
    @test C12 !== nothing
    @test size(C12) == (4, 5)
    @test all(>=(0), C12)
    @test all(>=(1), sum(C12; dims = 2))

    C30 = PCC.simulation(PCC.SumLift(), G3, G0; optimizer = OPTIMIZER)
    @test C30 !== nothing
    @test size(C30) == (1, 5)
    @test all(>=(1), C30)

    # Complete: no solution between G_4 and G_0, as the capsule finds, and any
    # graph dominates itself through the identity.
    @test PCC.simulation(PCC.SumLift(), G4, G0; optimizer = OPTIMIZER) === nothing
    @test PCC.simulation(PCC.SumLift(), G2, G2; optimizer = OPTIMIZER) !== nothing

    @test_throws ArgumentError PCC.simulation(PCC.SumLift(), G1, G2)
end

end # module
