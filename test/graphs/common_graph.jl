module TestCommonGraph

using Test
using HybridSystems
import PathCompleteCertificates as PCC

# The plant of Philippe, Essick, Dullerud & Jungers, §4, under each of its four
# controllers.
const A_PLANT = [0.94 0.14; 0.56 0.46]
const B_PLANT = [0.0; 1.0]
const GAINS = [[-0.49 0.27], [0.0 0.27], [-0.49 0.0], [0.0 0.0]]
const MODES = [A_PLANT + B_PLANT * K for K in GAINS]

@testset "the common graph is one node with a loop per mode" begin
    system = PCC.switched_system(MODES)
    one = PCC.common_graph(system)

    @test PCC.n_nodes(one) == 1
    @test PCC.n_edges(one) == 4
    @test sort(PCC.alphabet(one)) == 1:4
    @test PCC.is_path_complete(one, 1:PCC.n_modes(system))

    # A system on a restricting automaton is refused.
    constraint = GraphAutomaton(2)
    add_transition!(constraint, 1, 1, 1)
    add_transition!(constraint, 1, 2, 2)
    add_transition!(constraint, 2, 1, 1)
    @test_throws ArgumentError PCC.common_graph(
        HybridSystems.discreteswitchedsystem(MODES[1:2], constraint),
    )
end

@testset "a problem checks the graph against the system's modes" begin
    problem = PCC.StabilityProblem(PCC.switched_system(MODES))

    # The common graph is accepted ...
    model = PCC.optimization_model(
        PCC.QuadraticTemplate(),
        PCC.common_graph(problem.system),
        problem;
        rate = 1.0,
        optimizer = nothing,
    )
    @test model isa PCC.JuMP.Model

    # ... and a graph missing a mode is not.
    partial = GraphAutomaton(1)
    for mode in 1:3
        add_transition!(partial, 1, 1, mode)
    end
    @test_throws ArgumentError PCC.optimization_model(
        PCC.QuadraticTemplate(),
        partial,
        problem;
        rate = 1.0,
        optimizer = nothing,
    )
end

end # module
