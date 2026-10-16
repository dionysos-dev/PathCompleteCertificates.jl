"""
    AbstractRefinementAlgorithm

The supertype of the algorithms [`refine`](@ref) can run. A new algorithm
subtypes it and implements [`next_graph`](@ref).
"""
abstract type AbstractRefinementAlgorithm end

"""
    next_graph(algorithm, certificate; atol, solve)

The next graph after `certificate`, as `(lifted, next)`, or `nothing` if there
is none. `next` is the certificate on `lifted` if the algorithm already solved
it, `nothing` otherwise.

Edges with slack at most `atol` are tight; `solve(lifted)` solves a candidate.
"""
function next_graph end

"""
    initial_graph(algorithm, system)

The graph `refine(template, problem)` starts from: [`common_graph`](@ref) of
`system` unless `algorithm` says otherwise.
"""
initial_graph(::AbstractRefinementAlgorithm, system) = common_graph(system)
