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
include("refinements/split.jl")
include("refinements/product.jl")

include("lifts/abstract.jl")
include("lifts/dual.jl")
include("lifts/identity.jl")
include("lifts/subsets.jl")
include("lifts/sum.jl")
include("lifts/composition.jl")

include("systems/switched.jl")
include("systems/trajectory.jl")
include("systems/simulate.jl")

include("templates/abstract.jl")
include("problems/abstract.jl")

include("templates/linear_copositive.jl")
include("templates/dual_copositive.jl")
include("templates/quadratic.jl")
include("templates/polyhedral.jl")
include("templates/conic_polyhedral.jl")
include("templates/sum_of_squares.jl")

include("problems/stability.jl")
include("problems/safety.jl")
include("problems/optimal_control.jl")

include("systems/closed_loop.jl")
include("aggregation.jl")

include("refinements/strategies.jl")
include("refinements/loop.jl")
include("lifts/compare.jl")

end # module
