"""
    PathCompleteCertificates

Certificates for switched systems built on **path-complete graphs**.

A certificate here is always the same three things: a labelled graph, a function
drawn from a *template* at each node, and one inequality along each edge. What
changes between stability, optimal control and safety is only the edge
inequality — which is why the package is organised along two independent axes
rather than one type hierarchy:

  * **template** — what the node functions are (quadratic, polyhedral, …);
  * **objective** — what the edge inequality says (stability, optimal control,
    safety).

Adding an objective is one method, adding a template is two, and their
combination costs nothing. See `CLAUDE.md` for the full contract.
"""
module PathCompleteCertificates

include("graph.jl")
include("systems.jl")
include("problems/abstract.jl")
include("template.jl")
include("problems/stability.jl")
include("utils.jl")
include("problems/safety.jl")

end # module
