"""
    PathCompleteCertificates

Certificates for switched systems built on path-complete graphs: a labelled
graph, a function from a template at each node, and one inequality per edge.
"""
module PathCompleteCertificates

import HybridSystems
import JuMP
import LinearAlgebra
import MathematicalSystems
import Random

const _HS = HybridSystems
const _MS = MathematicalSystems

include("graphs/queries.jl")
include("graphs/words.jl")
include("graphs/path_completeness.jl")
include("graphs/dual.jl")
include("graphs/de_bruijn.jl")
include("graphs/observer.jl")
include("graphs/cycles.jl")
include("graphs/simulation.jl")

include("lifts/operations.jl")
include("lifts/abstract.jl")
include("lifts/dual.jl")
include("lifts/catalogue/identity.jl")
include("lifts/catalogue/out_split.jl")
include("lifts/catalogue/in_split.jl")
include("lifts/catalogue/forward_product.jl")
include("lifts/catalogue/backward_product.jl")
include("lifts/catalogue/path_dependent.jl")
include("lifts/catalogue/product.jl")
include("lifts/catalogue/min.jl")
include("lifts/catalogue/max.jl")
include("lifts/catalogue/sum.jl")
include("lifts/catalogue/composition.jl")
include("lifts/catalogue/backward_composition.jl")

include("systems/switched.jl")
include("systems/trajectory.jl")
include("systems/simulate.jl")

include("templates/abstract.jl")
include("problems/abstract.jl")
include("problems/certificate.jl")
include("problems/tight_edges.jl")

include("templates/catalogue/linear_copositive.jl")
include("templates/catalogue/dual_copositive.jl")
include("templates/catalogue/quadratic.jl")
include("templates/catalogue/parallel_faces_polyhedral.jl")
include("templates/catalogue/conic_polyhedral.jl")
include("templates/catalogue/sum_of_squares.jl")
include("templates/catalogue/set_prog.jl")

include("problems/catalogue/stability.jl")
include("problems/catalogue/safety.jl")
include("problems/catalogue/optimal_control.jl")

include("refinements/abstract.jl")
include("refinements/catalogue/tightest_node_splitting.jl")
include("refinements/catalogue/best_of_tight_edge_lifts.jl")
include("refinements/catalogue/hierarchy.jl")
include("refinements/refine.jl")
include("lifts/compare.jl")

end # module
