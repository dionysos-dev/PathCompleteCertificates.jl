"""
    PathCompleteCertificates

Certificates for switched systems built on **path-complete graphs**.

A certificate here is always the same three things: a labelled graph, a function
drawn from a *template* at each node, and one inequality along each edge. What
changes between stability, optimal control and safety is only the edge
inequality.
"""
module PathCompleteCertificates

include("graph_helper.jl")
include("systems.jl")
include("problems/abstract.jl")
include("template.jl")
include("extracting_common.jl")
include("problems/stability.jl")
include("utils.jl")
include("problems/safety.jl")
include("problems/optimal_control.jl")

end # module
