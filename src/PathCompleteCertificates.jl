"""
    PathCompleteCertificates

Certificates for switched systems built on **path-complete graphs**.

A certificate here is always the same three things: a labelled graph, a function
drawn from a *template* at each node, and one inequality along each edge. What
changes between stability, optimal control and safety is only the edge
inequality.
"""
module PathCompleteCertificates

include("operations.jl")

include("graphs/queries.jl")
include("graphs/words.jl")
include("graphs/predicates.jl")
include("graphs/languages.jl")
include("graphs/dual.jl")
include("graphs/de_bruijn.jl")
include("graphs/observer.jl")
include("graphs/cycles.jl")
include("graphs/simulation.jl")

include("refinements/abstract.jl")
include("refinements/dual.jl")
include("refinements/catalogue/forward_edge_split.jl")
include("refinements/catalogue/backward_edge_split.jl")
include("refinements/catalogue/forward_edge_product.jl")
include("refinements/catalogue/backward_edge_product.jl")
include("refinements/catalogue/path_dependent.jl")
include("refinements/catalogue/product.jl")

include("lifts/abstract.jl")
include("lifts/dual.jl")
include("lifts/catalogue/identity.jl")
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

include("templates/catalogue/linear_copositive.jl")
include("templates/catalogue/dual_copositive.jl")
include("templates/catalogue/quadratic.jl")
include("templates/catalogue/polyhedral.jl")
include("templates/catalogue/conic_polyhedral.jl")
include("templates/catalogue/sum_of_squares.jl")

include("problems/catalogue/stability.jl")
include("problems/catalogue/safety.jl")
include("problems/catalogue/optimal_control.jl")

include("systems/closed_loop.jl")
include("common.jl")

include("refinements/strategies.jl")
include("refinements/refine.jl")
include("lifts/compare.jl")

end # module
