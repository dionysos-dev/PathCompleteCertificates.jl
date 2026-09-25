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
# Pure graph transforms -- no template, no problem -- so they sit with the
# other graph foundations despite living in refinement/ (see that file).
include("refinement/lift.jl")
include("systems/switched.jl")
include("systems/trajectory.jl")
include("systems/simulate.jl")

# --- The two axes, declared before either is implemented ----------------------
# Both interfaces come first so each may mention the other's abstract type.
# Neither depends on the other's *implementations*, which is what matters.
include("templates/abstract.jl")   # AXIS 1 -- what the node functions are
include("problems/abstract.jl")    # AXIS 2 -- what the edge inequality says

# --- Axis 1: one file per template, each answering the whole interface --------
# Adding a template is adding a file here, and nothing else: the problems are
# written against the primitives, not against any template.
include("templates/linear_copositive.jl")
include("templates/quadratic.jl")
include("templates/polyhedral.jl")
include("templates/conic_polyhedral.jl")
# The methods live in ext/PathCompleteCertificatesSumOfSquaresExt.jl: the type
# is cheap, the polynomial stack behind it is not.
include("templates/sum_of_squares.jl")

# --- Axis 2: one file per problem, each composing those primitives ------------
include("problems/stability.jl")
include("problems/safety.jl")
include("problems/optimal_control.jl")

# --- The closed loop: simulation that depends on the problem axis ------------
# The rest of the systems files sit in the foundations above; this one
# dispatches on a certificate, so it can only be included once one exists.
include("systems/closed_loop.jl")

# --- The join: collapsing a certificate's node functions into one -------------
# Dispatches on the graph, not on the problem, so it sits with neither axis.
include("aggregation.jl")

# --- The co-design of graph and certificate: iterative lifting ---------------
# Reads graph, template and problem at once, like aggregation.jl above --
# except scoped to stability, so it is included once that problem exists
# rather than claimed as a third generic axis it does not yet have.
include("refinement/stability.jl")

end # module
