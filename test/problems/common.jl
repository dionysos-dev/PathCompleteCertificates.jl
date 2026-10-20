module TestCommon

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import LinearAlgebra

const A = [[0.5 0.0; 0.0 0.25], [0.25 0.0; 0.0 0.5]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))
const X = [1.0, 2.0]

const P1 = PCC.QuadraticFunction(LinearAlgebra.Symmetric([1.0 0.0; 0.0 1.0]))
const P2 = PCC.QuadraticFunction(LinearAlgebra.Symmetric([3.0 0.0; 0.0 3.0]))
const VS = [P1, P2]


    weights = [
        PCC.ParallelFacesPolyhedralFunction(
            Matrix{Float64}(LinearAlgebra.I, 2, 2),
            [1.0, 1.0],
        ),
        PCC.ParallelFacesPolyhedralFunction(
            Matrix{Float64}(LinearAlgebra.I, 2, 2),
            [4.0, 4.0],
        ),
    ]

    @test PCC.common(graph,
        PROBLEM,
        weights,
        X,
    ) ≈ minimum(
        PCC.node_value(PROBLEM, V, X) for
        V in weights
    )
end

end
