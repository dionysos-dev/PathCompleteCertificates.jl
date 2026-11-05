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
import SetProg

const _HS = HybridSystems
const _MS = MathematicalSystems

# Systems.
export switched_system, has_input, state_matrices, input_matrices
export simulate, Trajectory, states, inputs, switching

# Problems and certificates.
export StabilityProblem, SafetyProblem, OptimalControlProblem
export certify, optimization_model
export StabilityCertificate, SafetyCertificate, OptimalControlCertificate
export is_feasible, functions, node_value, status, common
export get_graph, get_template, get_problem
export edge_slacks, tight_edges, tight_subgraph
export objective, optimality_gap, jsr_lower_bound, is_jsr_exact

# Templates.
export QuadraticTemplate, SumOfSquaresTemplate, PiecewiseQuadraticTemplate
export PiecewiseLinearTemplate, DualPiecewiseLinearTemplate
export LinearCopositiveTemplate, DualCopositiveTemplate, planar_conic_partition

# Graphs.
export empty_graph, add_edge!, WordGraph, expanded_form
export de_bruijn, common_graph, dual
export is_path_complete, is_complete, is_co_complete, n_nodes, n_edges, n_modes

# Lifts and comparison.
export lift, Lifted, origins, is_valid, simulation
export IdentityLift, InSplitLift, OutSplitLift, ForwardProductLift, BackwardProductLift
export PathDependentLift, ProductLift, MinLift, MaxLift, SumLift
export CompositionLift, BackwardCompositionLift
export compare, Comparison, simulations, templates

# Refinement.
export refine, RefinementTrace, rates, graphs, certificates, steps
export AbstractRefinementStrategy, TightestNodeSplitting, BestOfTightEdgeLifts
export next_graph, initial_graph

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
include("problems/gauges.jl")
include("problems/sets.jl")
include("problems/certificate.jl")
include("problems/tight_edges.jl")

include("templates/catalogue/quadratic.jl")
include("templates/catalogue/sum_of_squares.jl")
include("templates/catalogue/piecewise_quadratic.jl")
include("templates/catalogue/piecewise_linear.jl")
include("templates/catalogue/dual_piecewise_linear.jl")
include("templates/catalogue/copositive.jl")

include("problems/catalogue/stability.jl")
include("problems/catalogue/safety.jl")
include("problems/catalogue/optimal_control.jl")
include("problems/catalogue/fixed_gain_optimal_control.jl")

include("refinements/abstract.jl")
include("refinements/catalogue/tightest_node_splitting.jl")
include("refinements/catalogue/best_of_tight_edge_lifts.jl")
include("refinements/refine.jl")
include("lifts/compare.jl")

end # module
