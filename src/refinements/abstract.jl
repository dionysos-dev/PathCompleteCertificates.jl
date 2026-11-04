"""
    AbstractRefinementStrategy

The supertype of the strategies [`refine`](@ref) can follow: the rule that
says where to lift the graph from its certificate. A new strategy subtypes it
and implements [`next_graph`](@ref).
"""
abstract type AbstractRefinementStrategy end

"""
    next_graph(strategy, certificate; atol, solve)

The next graph after `certificate`, as `(lifted, next)`, or `nothing` if there
is none. `next` is the certificate on `lifted` if the strategy already solved
it, `nothing` otherwise.

Edges with slack at most `atol` are tight; `solve(lifted)` solves a candidate.
"""
function next_graph end

"""
    initial_graph(strategy, system)

The graph `refine(template, problem)` starts from: [`common_graph`](@ref) of
`system` unless `strategy` says otherwise.
"""
initial_graph(::AbstractRefinementStrategy, system) = common_graph(system)
