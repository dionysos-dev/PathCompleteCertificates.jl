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
# those are proved for none of our templates yet. Nothing below reads the
# template except through `edge_slacks`, which every template answers, so
# widening the signature is the only edit that generalisation needs -- once the
# mathematics licenses it.
#
# Widening to another PROBLEM needs one concept this file does not have: the
# scalar the problem is trying to improve, and the driver that minimises it.
# Here those are `certificate.rate` and `jsr_bound`; safety would want `margin`.
# Naming that concept is the work -- copying this file is not.

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

These are the Lyapunov functions themselves, not only the bounds they attain, so
a refinement run can be drawn without solving anything a second time.
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

Whether a [`refine`](@ref) run stopped because no node was left whose tight edges
`lift` could separate.

`false` means it stopped for another reason: `depth_max` was reached, or
`until_stability` saw a certified rate below 1.
"""
is_converged(trace::RefinementTrace) = trace.converged

"""
    refine(template::QuadraticTemplate, graph, problem::StabilityProblem;
           optimizer, depth_max = 5, until_stability = false,
           lift = ForwardLift(), atol = 1e-4, rtol = 1e-6,
           rng = Random.default_rng())

Iteratively lift `graph` to tighten the stability certificate it carries, by the
greedy strategy of Ninite & Jungers, *Iterative graph lifting for automatic
design of path-complete stability certificates* (arXiv:2607.00637).

At each step [`jsr_bound`](@ref) certifies the current graph and
[`tight_edges`](@ref) reads off which edge inequalities the solution is held at.
A node whose tight edges fall into **two or more** copies of `lift`
([`copies`](@ref)) is being asked to serve two futures with one function, and
splitting it gives each its own. Nodes are scored by how many copies would
receive a tight edge, the highest score is taken, and ties are broken uniformly
at random via `rng`.

Counting *copies* rather than edges is what makes the rule honest about the lift
in hand: [`ForwardLift`](@ref) cannot separate two edges to the same successor,
so a node held at exactly those is no candidate for it, however tight they are.

The loop stops early once no such node remains: [`is_converged`](@ref) is then
`true`. Set `until_stability = true` to also stop as soon as the certified rate
drops below 1 — [`jsr_bound`](@ref) returns a rate the solver certified feasible,
so that is already a proof of stability and needs no margin.

Returns a [`RefinementTrace`](@ref), which carries the certificates themselves
and not merely the bounds.

## Choosing the two tolerances

`rtol` is the bisection tolerance of each [`jsr_bound`](@ref) call and `atol` the
one that decides tightness. They have to be read together: `rtol ≪ atol ≪ 1`.

Bisection stops at a rate slightly *above* the optimum, so the model is still
strictly feasible and a genuinely tight edge does not measure zero — it measures
about the bisection gap. On a rotation-and-shear pair over `de_bruijn(1, 2)` with
`rtol = 1e-6`, the three active edges measure `1.3e-7`, `6.0e-7` and `2.9e-6`
while the slack one measures `0.17`. Any `atol` between those two scales reads
the same set; the defaults sit in the middle of five orders of magnitude of room.

Lower `atol` towards `rtol` and active edges start being missed, so the search
ends early on a graph that could still be improved. Raise it and slack edges are
called tight, so a node is split for no gain.
"""
function refine(
    template::QuadraticTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    depth_max::Integer = 5,
    until_stability::Bool = false,
    lift::AbstractLift = ForwardLift(),
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

        node = _node_to_split(lift, certificate; atol = atol, rng = rng)

        if node === nothing
            converged = true
            break
        end

        graph = lift(graph, node)
    end

    return RefinementTrace(identity.(trace), converged)
end

"""
    _node_to_split(lift, certificate; atol, rng)

The node `lift` should be applied to next, or `nothing` when there is none.

A node scores the number of `lift`'s [`copies`](@ref) that would receive at least
one tight edge, and two is the minimum worth acting on: at one, every tight edge
stays together and the split frees nothing. The highest score wins and ties are
drawn with `rng`.

No graph is built to decide this, which is the point of `copies` answering in
terms of edges — the alternative is one lift per candidate, thrown away.
"""
function _node_to_split(
    lift::AbstractLift,
    certificate::StabilityCertificate;
    atol::Real,
    rng::Random.AbstractRNG,
)
    graph_ = graph(certificate)
    tight = Set(tight_edges(certificate; atol = atol))

    separated = zeros(Int, n_nodes(graph_))

    for node in nodes(graph_)
        for group in copies(lift, graph_, node)
            any(edge -> (node, dest(edge), label(graph_, edge)) in tight, group) &&
                (separated[node] += 1)
        end
    end

    best = maximum(separated)
    best > 1 || return nothing

    return rand(rng, [node for node in nodes(graph_) if separated[node] == best])
end
