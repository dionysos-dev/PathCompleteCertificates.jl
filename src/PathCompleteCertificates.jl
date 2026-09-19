"""
    PathCompleteCertificates

Certificates for switched systems built on **path-complete graphs**.

A certificate here is always the same three things: a labelled graph, a function
drawn from a *template* at each node, and one inequality along each edge. What
changes between stability, optimal control and safety is only the edge
inequality.
"""
module PathCompleteCertificates

# --- Foundations: what a certificate is built on ------------------------------
include("graphs/queries.jl")
include("graphs/predicates.jl")
include("graphs/de_bruijn.jl")
include("graphs/observer.jl")
include("systems.jl")

# --- The two axes, declared before either is implemented ----------------------
# Both interfaces come first so each may mention the other's abstract type: a
# template's `_node_value` is generic in the problem, and a problem's edge
# condition is generic in the template. Neither axis depends on the other's
# *implementations*, which is the property that matters.
include("templates/abstract.jl")   # AXIS 1 -- what the node functions are
include("problems/abstract.jl")    # AXIS 2 -- what the edge inequality says

# --- Axis 1: one file per template, each answering the whole interface --------
# Adding a template is adding a file here, and nothing else: the problems are
# written against the primitives, not against any template.
include("templates/linear_copositive.jl")
include("templates/quadratic.jl")
include("templates/polyhedral.jl")
include("templates/conic_polyhedral.jl")

# --- Axis 2: one file per problem, each composing those primitives ------------
include("problems/stability.jl")
include("problems/safety.jl")
include("problems/optimal_control.jl")

# --- The join: collapsing a certificate's node functions into one -------------
# Dispatches on the graph, not on the problem, so it sits with neither axis.
include("aggregation.jl")

end # module
