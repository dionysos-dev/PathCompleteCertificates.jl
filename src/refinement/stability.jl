# The co-design of graph and certificate from Ninite & Jungers, "Iterative
# graph lifting for automatic design of path-complete stability certificates"
# (arXiv:2607.00637, 2026): `refine` drives `jsr_bound`/`certify` and the lifts
# of `lift.jl` together, so it belongs to neither axis of CLAUDE.md's section 2
# -- it reads the graph, a template and a problem at once, exactly the reason
# `aggregation.jl` is top-level rather than filed under one of them.
#
# Scoped to `QuadraticTemplate` and `StabilityProblem` on purpose, and the
# reason is soundness rather than plumbing: whether a lift may be applied at all
# depends on the closure properties of the template (CLAUDE.md section 5), and
# those are proved for none of our templates yet. Everything below is written
# against `edge_slacks`, which every template answers, so widening the signature
# is the only edit that generalisation needs -- once the mathematics licenses it.

import Random

"""
    RefinementTrace(certificates, converged)

The record of one [`refine`](@ref) run: one [`StabilityCertificate`](@ref) per
graph visited, the seed graph's first.

A certificate carries its own graph and rate, so [`graphs`](@ref) and
[`rates`](@ref) read them off rather than storing them again — they cannot
disagree about how many steps were taken.
"""
struct RefinementTrace{C <: StabilityCertificate}
    certificates::Vector{C}
    converged::Bool
end

"""
    certificates(trace)

The certificate solved on each graph a [`refine`](@ref) run visited.

These are the Lyapunov functions themselves, not only the bounds they attain,
so a refinement run can be drawn without solving anything a second time.
"""
certificates(trace::RefinementTrace) = trace.certificates

"""
    graphs(trace)

The graphs visited by a [`refine`](@ref) run, the seed graph first.
"""
graphs(trace::RefinementTrace) = [graph(certificate) for certificate in trace.certificates]

"""
    rates(trace)

The joint-spectral-radius bound certified on each of [`graphs`](@ref), in the
same order.
"""
rates(trace::RefinementTrace) = [certificate.rate for certificate in trace.certificates]

"""
    is_converged(trace) -> Bool

Whether a [`refine`](@ref) run stopped because no node was left that the lift
could usefully split — every node either has at most one tight outgoing edge,
or the lift cannot separate the ones it has.

`false` means it stopped for another reason: `depth_max` was reached, or
`until_stability` saw a certified rate below 1.
"""
is_converged(trace::RefinementTrace) = trace.converged

"""
    refine(template::QuadraticTemplate, graph, problem::StabilityProblem;
           optimizer, depth_max = 5, until_stability = false,
           lift = forward_lift, atol = 1e-4, rtol = 1e-6,
           rng = Random.default_rng())

Iteratively lift `graph` to tighten the stability certificate it carries, by the
greedy strategy of Ninite & Jungers, *Iterative graph lifting for automatic
design of path-complete stability certificates* (arXiv:2607.00637).

At each step [`jsr_bound`](@ref) certifies the current graph, and
[`tight_edges`](@ref) reads off which edge inequalities the solution is held at.
A node with **two or more** tight outgoing edges is being asked to serve two
futures with one function; splitting it with `lift` — [`forward_lift`](@ref)
(the paper's, and the default) or [`forward_edge_lift`](@ref) — gives each
future its own function and can only relax the problem. Ties are broken
uniformly at random via `rng`.

The loop stops early once no such node remains *that the lift can actually
split*: [`is_converged`](@ref) is then `true`. Set `until_stability = true` to
also stop as soon as the certified rate drops below 1 — [`jsr_bound`](@ref)
returns a rate the solver certified feasible, so that is already a proof of
stability and needs no further margin.

!!! note "The default lift cannot refine the memoryless graph"
    [`forward_lift`](@ref) splits by distinct successor, and the one-node graph
    has only itself, so `refine` on it converges at once having certified the
    memoryless bound and nothing more. [`forward_edge_lift`](@ref) does refine
    it: on a rotation-and-shear pair it walks `0.976, 0.925, 0.907, 0.904` over
    one, two, three and four nodes — and its four-node graph beats
    `de_bruijn(2, 2)`, which also has four nodes, at `0.905`.

Returns a [`RefinementTrace`](@ref), which carries the certificates themselves
and not merely the bounds.

## Choosing the two tolerances

`rtol` is the bisection tolerance of each [`jsr_bound`](@ref) call and `atol`
the one that decides tightness, and they have to be read together:
`rtol ≪ atol ≪ 1`.

Bisection stops at a rate slightly *above* the optimum, so the model is still
strictly feasible and a genuinely tight edge does not measure zero — it measures
about the bisection gap. On a rotation-and-shear pair over `de_bruijn(1, 2)`
with `rtol = 1e-6`, the three active edges measure `1.3e-7`, `6.0e-7` and
`2.9e-6` while the slack one measures `0.17`. Any `atol` between those two
scales reads the same set; the defaults sit in the middle of five orders of
magnitude of room.

Lower `atol` towards `rtol` and active edges start being missed, so the loop
converges early on a graph that could still be improved. Raise it and slack
edges are called tight, so a node is split for no gain.

!!! warning "Both stopping conditions are heuristics, not theorems"
    Neither exhausts the search. `is_converged` says this lift has nothing left
    to separate, not that the graph attains the exact joint spectral radius; a
    different lift, or a template of higher degree, may still do better.
"""
function refine(
    template::QuadraticTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    depth_max::Integer = 5,
    until_stability::Bool = false,
    lift = forward_lift,
    atol::Real = 1e-4,
    rtol::Real = 1e-6,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))

    trace = StabilityCertificate[]
    converged = false

    for depth in 1:depth_max
        certificate = jsr_bound(template, graph, problem; optimizer, rtol = rtol)

        is_feasible(certificate) || throw(
            ArgumentError(
                "no certificate for $(template) on the graph reached at depth $depth",
            ),
        )

        push!(trace, certificate)

        depth == depth_max && break
        until_stability && certificate.rate < 1 && break

        node = _node_to_split(certificate, lift; atol = atol, rng = rng)

        if node === nothing
            converged = true
            break
        end

        graph = lift(graph, node)
    end

    return RefinementTrace(identity.(trace), converged)
end

"""
    _node_to_split(certificate, lift; atol, rng)

The node `lift` should be applied to next, or `nothing` when there is none.

Candidates are the nodes with the most tight outgoing edges, and at least two of
them — below that, splitting frees nothing. Among equals, one is drawn with
`rng`.

A candidate that `lift` cannot actually split is dropped, and this is not an
edge case: `forward_lift` splits by distinct *successor* while tightness is
counted per *edge*, so the memoryless one-node graph — two tight self-loops, one
successor — is selected by the count and left unchanged by the lift. Without
this filter `refine` re-solves the same graph until `depth_max`, reporting no
convergence and no error.

Asking the lift is cheaper than reasoning about its grain: the lifts are pure
graph transforms, and one of them costs nothing next to the bisection that
produced `certificate`.
"""
function _node_to_split(
    certificate::StabilityCertificate,
    lift;
    atol::Real,
    rng::Random.AbstractRNG,
)
    graph_ = graph(certificate)

    tight = Dict(node => 0 for node in nodes(graph_))

    for (source_node, _, _) in tight_edges(certificate; atol = atol)
        tight[source_node] += 1
    end

    # Sorted, so a given `rng` gives the same run twice over.
    candidates = sort([node for (node, count) in tight if count > 1])

    filter!(node -> n_nodes(lift(graph_, node)) > n_nodes(graph_), candidates)

    isempty(candidates) && return nothing

    best = maximum(tight[node] for node in candidates)

    return rand(rng, filter(node -> tight[node] == best, candidates))
end
