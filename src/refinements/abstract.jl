"""
    AbstractRefinementAlgorithm

How [`refine`](@ref) chooses the next graph: [`next_graph`](@ref) reads a
certificate and returns a lifted graph, and [`initial_graph`](@ref) says where
a run starts.
"""
abstract type AbstractRefinementAlgorithm end

"""
    next_graph(algorithm, certificate; atol, solve) -> Union{Nothing, Tuple{Lifted, Any}}

The graph [`refine`](@ref) moves to after `certificate`, as a
[`Lifted`](@ref), with its certificate when `algorithm` solved it to choose and
`nothing` otherwise; or `nothing` alone when the algorithm has no next graph.
The loop takes what it returns. `atol` decides which edges are tight, and
`solve(lifted)` returns the certificate on a candidate.
"""
function next_graph end

"""
    initial_graph(algorithm, system)

The graph `refine(template, problem)` starts from: [`common_graph`](@ref) of
`system` unless `algorithm` says otherwise.
"""
initial_graph(::AbstractRefinementAlgorithm, system) = common_graph(system)
