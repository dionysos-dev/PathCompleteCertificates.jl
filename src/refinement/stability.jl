# The co-design of graph and certificate from Ninite & Jungers, "Iterative
# graph lifting for automatic design of path-complete stability certificates"
# (arXiv:2607.00637, 2026): `refine` drives `jsr_bound`/`certify` and the lifts
# of `lift.jl` together, so it belongs to neither axis of CLAUDE.md's section 2
# -- it reads the graph, a template and a problem at once, exactly the reason
# `aggregation.jl` is top-level rather than filed under one of them.
#
# Scoped to `QuadraticTemplate` and `StabilityProblem` on purpose: choosing
# which node to lift reads the slack of the fitted `P` matrices, which is a
# quadratic-template notion. Generalising it to another template or problem is
# future work, not something to fake here.

import LinearAlgebra
import Random

"""
    RefinementTrace(graphs, rates, converged)

The record of one [`refine`](@ref) run: the graphs visited in order (the seed
first), the joint-spectral-radius bound [`jsr_bound`](@ref) certified on each,
and whether the loop stopped because no further lift could tighten it.

`graphs` and `rates` have the same length: entry `k` of `rates` is the bound
certified on entry `k` of `graphs`.
"""
struct RefinementTrace{T <: Real}
    graphs::Vector{_HS.GraphAutomaton}
    rates::Vector{T}
    converged::Bool
end

"""
    graphs(trace)

The graphs visited by a [`refine`](@ref) run, the seed graph first.
"""
graphs(trace::RefinementTrace) = trace.graphs

"""
    rates(trace)

The joint-spectral-radius bound certified on each of [`graphs`](@ref), in the
same order.
"""
rates(trace::RefinementTrace) = trace.rates

"""
    is_converged(trace) -> Bool

Whether a [`refine`](@ref) run stopped because no node had more than one tight
outgoing domination constraint -- lifting further could not relax anything.
`false` means it stopped for another reason: `depth_max` was reached, or
`until_stability` saw a certified rate below 1.
"""
is_converged(trace::RefinementTrace) = trace.converged

"""
    refine(template::QuadraticTemplate, graph, problem::StabilityProblem;
           optimizer, depth_max = 5, until_stability = false,
           lifting_function = forward_lift, tol = 1e-4, rtol = 1e-6,
           rng = Random.default_rng())

Iteratively lift `graph` to tighten the stability certificate it carries, by
the greedy strategy of Ninite & Jungers (2026), arXiv:2607.00637.

At each step, [`jsr_bound`](@ref) certifies the current graph. A domination
constraint on edge `(a, b, i)` is *tight* when its slack

    rate^rate_exponent(template) * P_a - A_i' * P_b * A_i

has smallest eigenvalue below `tol`: the template has no room left there, so
lifting elsewhere would not help. The node with the most tight *outgoing*
constraints is lifted with `lifting_function` -- [`forward_lift`](@ref) (the
default) or [`forward_edge_lift`](@ref) -- and ties are broken uniformly at
random via `rng`.

The loop stops early, before `depth_max` steps, once no node has more than one
tight outgoing constraint: [`is_converged`](@ref) is then `true` on the
returned trace. Set `until_stability = true` to also stop as soon as the
certified rate drops below `1 - tol`, i.e. the current graph already proves
stability.

`rtol` is the bisection tolerance passed to each [`jsr_bound`](@ref) call, kept
tight (and separate from `tol`) on purpose: a constraint whose true slack is
zero still measures around `rtol` once bisection stops, so `rtol` must stay
well below `tol` or a genuinely tight edge is missed and the loop converges
too early.

Returns a [`RefinementTrace`](@ref).
"""
function refine(
    template::QuadraticTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    depth_max::Integer = 5,
    until_stability::Bool = false,
    lifting_function::Function = forward_lift,
    tol::Real = 1e-4,
    rtol::Real = 1e-6,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))

    A = mode_matrices(problem.system)

    trace_graphs = _HS.GraphAutomaton[graph]
    trace_rates = Float64[]
    converged = false

    for depth in 1:depth_max
        certificate = jsr_bound(template, graph, problem; optimizer, rtol = rtol)

        is_feasible(certificate) || throw(
            ArgumentError(
                "no certificate for $(template) on the graph reached at depth $depth",
            ),
        )

        push!(trace_rates, certificate.rate)

        depth == depth_max && break
        until_stability && certificate.rate < 1 - tol && break

        tight = _tight_outgoing_count(template, graph, certificate, A; tol = tol)

        max_tight = maximum(values(tight))
        if max_tight <= 1
            converged = true
            break
        end

        candidates = [node for node in nodes(graph) if tight[node] == max_tight]
        node = rand(rng, candidates)

        graph = lifting_function(graph, node)
        push!(trace_graphs, graph)
    end

    return RefinementTrace(trace_graphs, trace_rates, converged)
end

"""
    _tight_outgoing_count(template, graph, certificate, A; tol)

For each node of `graph`, how many of its outgoing domination constraints are
tight -- within `tol` of equality -- at the solution `certificate` carries.

The slack of edge `(a, b, i)` is `rate^rate_exponent(template) * P_a -
A_i' * P_b * A_i`, exactly [`add_domination!`](@ref)'s inequality for
[`QuadraticTemplate`](@ref) evaluated at the fitted matrices; recomputing it
here is cheaper than plumbing dual values back out of the JuMP model `certify`
already discarded.
"""
function _tight_outgoing_count(
    template::QuadraticTemplate,
    graph::_HS.GraphAutomaton,
    certificate::StabilityCertificate,
    A::AbstractVector{<:AbstractMatrix};
    tol::Real,
)
    V = functions(certificate)
    scale = certificate.rate^rate_exponent(template)

    tight = Dict(node => 0 for node in nodes(graph))

    for edge in edges(graph)
        α, β, σ = source(edge), dest(edge), label(graph, edge)

        slack = scale * Matrix(V[α]) - A[σ]' * Matrix(V[β]) * A[σ]
        LinearAlgebra.eigmin(LinearAlgebra.Symmetric(slack)) < tol && (tight[α] += 1)
    end

    return tight
end
