module TestDualCopositive

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import HiGHS

# G_4 of the HSCC 2023 capsule. The one-node graph simulates every graph, so no
# graph certifies a larger rate than it does.
const G4 = GraphAutomaton(5)
for (a, b, mode) in [
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
]
    add_transition!(G4, a, b, mode)
end

# A positive system on which, with the weights floored at 1e-3, HiGHS's
# absolute tolerance let the one-node graph certify a smaller rate than G_4.
const SYSTEM = PCC.switched_system([[9.007 0.274; 2.069 8.272], [0.014 2.458; 8.874 1.281]])

@testset "the weight floor keeps the solver's tolerance out of the rate" begin
    template = PCC.DualCopositiveTemplate()
    @test template.min_weight == 1

    problem = PCC.StabilityProblem(SYSTEM)
    rate(graph) =
        PCC.jsr_bound(template, graph, problem; optimizer = HiGHS.Optimizer, rtol = 1e-9).rate

    @test rate(PCC.common_graph(2)) >= rate(G4) * (1 - 1e-7)
end

@testset "the template applies to positive systems only" begin
    template = PCC.DualCopositiveTemplate()
    @test PCC.is_applicable(template, SYSTEM)
    @test !PCC.is_applicable(template, PCC.switched_system([[0.5 -0.1; 0.0 0.5]]))
    @test_throws ArgumentError PCC.DualCopositiveTemplate(; min_weight = 0)
end

end # module
