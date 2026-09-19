using Test
using HybridSystems
import PathCompleteCertificates as PCC

@testset "Observer graph" begin
    graph = GraphAutomaton(2)
    add_transition!(graph, 1, 1, 1)
    add_transition!(graph, 1, 2, 2)
    add_transition!(graph, 2, 1, 1)

    observer, states = PCC.observer_graph(graph)

    @test states == [Set([1, 2]), Set([1]), Set([2])]
    @test PCC.n_nodes(observer) == 3
    @test PCC.n_edges(observer) == 5
    @test [
        (PCC.source(edge), PCC.dest(edge), PCC.label(observer, edge)) for
        edge in PCC.edges(observer)
    ] == [(1, 2, 1), (1, 3, 2), (2, 2, 1), (2, 3, 2), (3, 2, 1)]

    # The missing label-2 transition from node 2 produces no empty observer state.
    @test all(!isempty(state) for state in states)
end
