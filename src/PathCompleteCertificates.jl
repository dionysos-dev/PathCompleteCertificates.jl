"""
    PathCompleteCertificates

Certificates for switched systems built on **path-complete graphs**.

A certificate here is always the same three things: a labelled graph, a function
drawn from a *template* at each node, and one inequality along each edge. What
changes between stability, optimal control and safety is only the edge
inequality.
"""
module PathCompleteCertificates

# --- The vocabulary both axes and the lifts share -----------------------------
# A template declares which operations it is closed under; a lift names which
# it requires. Neither owns the words, so they come first.
include("operations.jl")

# --- Foundations: what a certificate is built on ------------------------------
# The adapter in queries.jl is the only file that touches HybridSystems' graph
# internals; everything else reads and writes graphs through it.
include("graphs/queries.jl")
include("graphs/words.jl")
include("graphs/predicates.jl")
include("graphs/languages.jl")
include("graphs/dual.jl")
include("graphs/de_bruijn.jl")
include("graphs/observer.jl")
include("graphs/cycles.jl")
include("graphs/simulation.jl")
# Transformations of the graph. A lift is a map on graphs preserving
# path-completeness, so it reads no template and no problem and belongs with the
# graph foundations it transforms. `refine` is one consumer; the ordering of two
# graphs is the other.
include("lifts/abstract.jl")
include("lifts/dual.jl")
include("lifts/split.jl")
include("lifts/product.jl")
include("lifts/composition.jl")
include("lifts/subsets.jl")
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
include("templates/dual_copositive.jl")
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
# Reads graph, template and problem at once, like aggregation.jl above, and
# names no problem: what it needs from one is four methods of the problem
# interface, which stability implements.
include("refinement/strategies.jl")
include("refinement/loop.jl")

# --- Comparing two graphs for a template -------------------------------------
# Reads graphs, a template's closures and a linear program, so it belongs to
# neither axis either.
include("ordering.jl")

end # module
