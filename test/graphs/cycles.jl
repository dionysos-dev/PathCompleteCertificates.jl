module TestGraphCycles

using Test
using HybridSystems
import PathCompleteCertificates as PCC

# Write a cycle as the nodes it visits, so the tests read as graph facts rather
# than as transition objects.
nodes_of(graph, cycle) = [PCC.source(edge) for edge in cycle]
labels_of(graph, cycle) = [PCC.label(graph, edge) for edge in cycle]

@testset "a self-loop is a cycle of length one" begin
    graph = GraphAutomaton(1)
    add_transition!(graph, 1, 1, 1)
    add_transition!(graph, 1, 1, 2)

    cycles = PCC.simple_cycles(graph)

    @test length(cycles) == 2
    @test all(cycle -> nodes_of(graph, cycle) == [1], cycles)
    @test sort(reduce(vcat, labels_of.(Ref(graph), cycles))) == [1, 2]
end

@testset "each cycle is returned once, not once per rotation" begin
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 2, 3, 1)
    add_transition!(graph, 3, 1, 1)

    cycles = PCC.simple_cycles(graph)

    # One triangle, written from its lowest node -- not three rotations of it.
    @test length(cycles) == 1
    @test nodes_of(graph, only(cycles)) == [1, 2, 3]
end

@testset "parallel edges make distinct cycles" begin
    graph = GraphAutomaton(2)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 2, 1, 1)
    add_transition!(graph, 2, 1, 2)

    # Same two nodes, but two ways back: two cycles, not one.
    @test length(PCC.simple_cycles(graph)) == 2
end

@testset "max_length bounds the search" begin
    graph = GraphAutomaton(4)
    for (a, b) in ((1, 2), (2, 3), (3, 4), (4, 1))
        add_transition!(graph, a, b, 1)
    end
    add_transition!(graph, 1, 1, 2)

    @test length(PCC.simple_cycles(graph)) == 2            # the self-loop and the square
    @test length(PCC.simple_cycles(graph; max_length = 3)) == 1   # only the self-loop
    @test length(PCC.simple_cycles(graph; max_length = 1)) == 1

    @test_throws ArgumentError PCC.simple_cycles(graph; max_length = 0)
end

@testset "an acyclic graph has no cycles" begin
    graph = GraphAutomaton(3)
    add_transition!(graph, 1, 2, 1)
    add_transition!(graph, 2, 3, 1)

    @test isempty(PCC.simple_cycles(graph))
    @test isempty(PCC.simple_cycles(GraphAutomaton(2)))
end

@testset "De Bruijn: every node lies on a cycle" begin
    graph = PCC.de_bruijn(2, 2)
    cycles = PCC.simple_cycles(graph)

    covered = unique(reduce(vcat, nodes_of.(Ref(graph), cycles)))

    @test sort(covered) == collect(PCC.nodes(graph))
    @test all(cycle -> allunique(nodes_of(graph, cycle)), cycles)
end

end # module
