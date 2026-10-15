module TestLiftComposition

import SetProg
using Test
using HybridSystems
import PathCompleteCertificates as PCC

edgeset(g) = Set((PCC.source(e), PCC.dest(e), PCC.label(g, e)) for e in PCC.edges(g))

function graph(edges, n)
    g = GraphAutomaton(n)
    for (a, b, l) in edges
        add_transition!(g, a, b, l)
    end
    return g
end

# Jongeneel & Jungers, Fig. 1: G1 and G2 are the backward and forward
# 1-composition lifts of the one-node graph (their Example III.2).
const JJ_G1 = graph([(1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2)], 2)
const JJ_G2 = graph([(1, 1, 1), (1, 2, 1), (2, 2, 2), (2, 1, 2)], 2)
const ONE = PCC.common_graph(2)

@testset "the composition lift of the one-node graph, forward and backward" begin
    forward = PCC.lift(PCC.CompositionLift(1), ONE)
    g = PCC.graph(forward)
    @test PCC.n_nodes(g) == 2
    @test PCC.origins(forward) == [(1, [1]), (1, [2])]
    @test edgeset(g) == edgeset(JJ_G2)
    @test PCC.is_path_complete(g, 1:2)

    backward = PCC.lift(PCC.BackwardCompositionLift(1), ONE)
    @test edgeset(PCC.graph(backward)) == edgeset(JJ_G1)
    @test PCC.BackwardCompositionLift(1) == PCC.dual(PCC.CompositionLift(1))

    @test PCC.requirements(PCC.CompositionLift(2)) == (PCC.Composition(),)
    @test PCC.requirements(PCC.BackwardCompositionLift(2)) == (PCC.InverseComposition(),)
    @test_throws ArgumentError PCC.CompositionLift(0)
end

@testset "its simulation is the map into (node, word) pairs (Example III.2)" begin
    @test PCC.simulation(PCC.IdentityLift(), JJ_G2, ONE) === nothing
    @test PCC.simulation(PCC.CompositionLift(1), ONE, JJ_G2) == [(1, [1]), (1, [2])]
    @test PCC.simulation(PCC.BackwardCompositionLift(1), ONE, JJ_G1) == [(1, [1]), (1, [2])]
    @test PCC.simulation(PCC.CompositionLift(1), ONE, JJ_G1) === nothing
end

@testset "validity needs invertible dynamics, read from the system" begin
    invertible = PCC.switched_system([[0.5 0.0; 0.0 0.5], [0.0 0.5; 0.5 0.0]])
    singular = PCC.switched_system([[0.5 0.0; 0.0 0.0], [0.0 0.5; 0.5 0.0]])

    @test PCC._is_invertible(invertible)
    @test !PCC._is_invertible(singular)
    @test PCC.is_valid(
        PCC.CompositionLift(1),
        SetProg.Ellipsoid(symmetric = true),
        invertible,
    )
    @test !PCC.is_valid(
        PCC.CompositionLift(1),
        SetProg.Ellipsoid(symmetric = true),
        singular,
    )
    @test PCC.is_valid(
        PCC.BackwardCompositionLift(1),
        SetProg.Ellipsoid(symmetric = true),
        invertible,
    )
    @test !PCC.is_valid(
        PCC.CompositionLift(1),
        PCC.ParallelFacesPolyhedralTemplate(1, 2),
        invertible,
    )
end

@testset "a larger graph has |S|·M^T nodes" begin
    g = PCC.de_bruijn(1, 2)
    lifted = PCC.lift(PCC.CompositionLift(2), g)
    @test PCC.n_nodes(PCC.graph(lifted)) == 2 * 4
    @test PCC.n_edges(PCC.graph(lifted)) == PCC.n_edges(g) * 4
    @test PCC.is_path_complete(PCC.graph(lifted), 1:2)
end

end # module
