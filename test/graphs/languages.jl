module TestGraphLanguages

using Test
using HybridSystems
import PathCompleteCertificates as PCC

# The plant of Philippe, Essick, Dullerud & Jungers, §4: a controller whose
# parts fail, under the rule that the same part never fails twice in a row.
const A_PLANT = [0.94 0.14; 0.56 0.46]
const B_PLANT = [0.0; 1.0]
const GAINS = [[-0.49 0.27], [0.0 0.27], [-0.49 0.0], [0.0 0.0]]
const MODES = [A_PLANT + B_PLANT * K for K in GAINS]

# States: 1 = working, 2 = first part failed last, 3 = second part failed last,
# 4 = both failed last. A part that just failed cannot fail again.
function failure_automaton()
    a = GraphAutomaton(4)
    for from in 1:4
        add_transition!(a, from, 1, 1)
    end
    add_transition!(a, 1, 2, 2)
    add_transition!(a, 3, 2, 2)
    add_transition!(a, 1, 3, 3)
    add_transition!(a, 2, 3, 3)
    add_transition!(a, 1, 4, 4)
    return a
end

@testset "the language of a system is its automaton" begin
    arbitrary = PCC.switched_system(MODES)
    @test PCC.language(arbitrary) isa OneStateAutomaton

    constrained = PCC.switched_system(MODES; automaton = failure_automaton())
    @test PCC.language(constrained) isa GraphAutomaton
    @test PCC.n_nodes(PCC.language(constrained)) == 4
end

@testset "the seed reads the language by construction" begin
    arbitrary = PCC.switched_system(MODES)
    one = PCC.seed(arbitrary)
    @test PCC.n_nodes(one) == 1
    @test PCC.n_edges(one) == 4
    @test PCC.is_path_complete(one, PCC.language(arbitrary))

    constrained = PCC.switched_system(MODES; automaton = failure_automaton())
    auto = PCC.seed(constrained)
    @test PCC.n_nodes(auto) == 4
    @test PCC.n_edges(auto) == 9
    @test PCC.is_path_complete(auto, PCC.language(constrained))

    # The automaton does not read every word: mode 2 twice in a row is not
    # admissible, so it is not path-complete for arbitrary switching.
    @test !PCC.is_path_complete(auto, 1:4)
end

@testset "path-completeness against an automaton is language inclusion" begin
    constraint = failure_automaton()

    # A complete graph reads everything, so any language.
    @test PCC.is_path_complete(PCC.de_bruijn(1, 4), constraint)

    # A one-node graph missing mode 4 reads nothing the constraint says with 4.
    partial = GraphAutomaton(1)
    for mode in 1:3
        add_transition!(partial, 1, 1, mode)
    end
    @test !PCC.is_path_complete(partial, constraint)

    # A graph that forbids "2 then 3" is not path-complete for the constraint,
    # which admits it.
    forbids = GraphAutomaton(2)
    add_transition!(forbids, 1, 1, 1)
    add_transition!(forbids, 1, 1, 3)
    add_transition!(forbids, 1, 1, 4)
    add_transition!(forbids, 1, 2, 2)
    add_transition!(forbids, 2, 1, 1)
    add_transition!(forbids, 2, 1, 4)
    add_transition!(forbids, 2, 2, 2)
    @test !PCC.is_path_complete(forbids, constraint)

    # The one-state automaton is the alphabet.
    @test PCC.is_path_complete(PCC.de_bruijn(1, 2), OneStateAutomaton(2))
    @test !PCC.is_path_complete(PCC.de_bruijn(1, 2), OneStateAutomaton(3))
end

@testset "a problem checks the graph against the system's language" begin
    constrained = PCC.switched_system(MODES; automaton = failure_automaton())
    problem = PCC.StabilityProblem(constrained)

    # The automaton itself is accepted as a certificate graph ...
    model = PCC.optimization_model(
        PCC.QuadraticTemplate(),
        PCC.seed(constrained),
        problem,
        1.0;
        optimizer = nothing,
    )
    @test model isa PCC.JuMP.Model

    # ... and a graph missing an admissible transition is not.
    partial = GraphAutomaton(1)
    for mode in 1:3
        add_transition!(partial, 1, 1, mode)
    end
    @test_throws ArgumentError PCC.optimization_model(
        PCC.QuadraticTemplate(),
        partial,
        problem,
        1.0;
        optimizer = nothing,
    )
end

end # module
