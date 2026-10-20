module TestCertificate

# One certificate type per problem, sharing an interface: the shared part is
# accessed through methods and stored once in `CertificateData`; what a problem
# certifies is a typed field on its own certificate type.

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import JuMP
import LinearAlgebra

const OPTIMIZER = Clarabel.Optimizer

const GRAPH = GraphAutomaton(2)
add_transition!(GRAPH, 1, 2, 1)
add_transition!(GRAPH, 2, 1, 1)

const SYSTEM = PCC.switched_system([[0.5 0.0; 0.0 0.25]])
const PROBLEM = PCC.StabilityProblem(SYSTEM)

const STABILITY = PCC.jsr_bound(
    PCC.QuadraticTemplate(),
    GRAPH,
    PROBLEM;
    optimizer = OPTIMIZER,
    rtol = 1e-2,
)

@testset "the accessors are the interface" begin
    @test STABILITY isa PCC.StabilityCertificate
    @test STABILITY isa PCC.AbstractCertificate
    @test PCC.is_feasible(STABILITY)
    @test length(PCC.functions(STABILITY)) == PCC.n_nodes(GRAPH)
    @test PCC.status(STABILITY) isa JuMP.MOI.TerminationStatusCode
    @test STABILITY.rate > 0
    @test PCC.problem(STABILITY) === PROBLEM
    @test PCC.graph(STABILITY) === GRAPH
end

@testset "a certificate is callable, and is the common function" begin
    x = [1.0, 2.0]

    @test STABILITY(x) ≈
          PCC.common(GRAPH, PROBLEM, PCC.functions(STABILITY), x)
