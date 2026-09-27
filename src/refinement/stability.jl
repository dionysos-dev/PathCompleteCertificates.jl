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
    RefinementStatus

Why a [`refine`](@ref) run stopped. Four outcomes, because a `Bool` cannot say
which of them happened and the difference decides what to do next.
"""
@enum RefinementStatus NOTHING_TO_SPLIT STALLED DEPTH_EXHAUSTED STABLE

"""
    NOTHING_TO_SPLIT

No node had tight outgoing edges in two different copies of the lift, so no
split could relax anything. The search is exhausted **for this lift**.
"""
NOTHING_TO_SPLIT

"""
    STALLED

A lift stopped buying anything: the certified rate failed to improve, `stall_max`
times in a row.

Not the same as [`NOTHING_TO_SPLIT`](@ref), and the difference is the whole
reason this outcome exists. A graph that already attains the exact joint spectral
radius holds *every* edge tight, so it always looks splittable and never
converges — it stalls. Without this outcome such a run grows the graph forever at
a constant bound.
"""
STALLED

"""
    DEPTH_EXHAUSTED

`depth_max` certificates were solved with the search still making progress.
Raise it.
"""
DEPTH_EXHAUSTED

"""
    STABLE

`until_stability` was set and the certified rate dropped below 1, which already
proves the system stable. Nothing further was attempted.
"""
STABLE

"""
    RefinementTrace(certificates, status)

The record of one [`refine`](@ref) run: one [`StabilityCertificate`](@ref) per
graph visited, the seed graph's first, and a [`RefinementStatus`](@ref) saying
why it stopped.

A certificate carries its own graph and rate, so [`graphs`](@ref) and
[`rates`](@ref) read them off rather than storing them again — they cannot
disagree about how many steps were taken.
"""
struct RefinementTrace{C <: StabilityCertificate}
    certificates::Vector{C}
    status::RefinementStatus
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
    status(trace::RefinementTrace)

Why the run stopped, as a [`RefinementStatus`](@ref).
"""
status(trace::RefinementTrace) = trace.status

"""
    is_converged(trace) -> Bool

Whether the search ended because this lift had nothing left to give —
[`NOTHING_TO_SPLIT`](@ref) or [`STALLED`](@ref).

The derived predicate over [`status`](@ref), as [`is_feasible`](@ref) is over a
certificate's. Read `status` when the difference matters, which it usually does:
one says no split was available, the other that the splits taken stopped paying.
"""
is_converged(trace::RefinementTrace) = status(trace) in (NOTHING_TO_SPLIT, STALLED)

"""
    refine(template::QuadraticTemplate, graph, problem::StabilityProblem;
           optimizer, depth_max = 5, until_stability = false,
           lift = ForwardLift(), atol = 1e-4, rtol = 1e-6, stall_max = 1,
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

Returns a [`RefinementTrace`](@ref), which carries the certificates themselves
and not merely the bounds, and a [`RefinementStatus`](@ref) saying which of the
four ways the run ended.

## Stopping

- no candidate node → [`NOTHING_TO_SPLIT`](@ref);
- `stall_max` lifts in a row failing to improve the rate by more than `rtol` →
  [`STALLED`](@ref);
- `depth_max` certificates solved → [`DEPTH_EXHAUSTED`](@ref);
- `until_stability` and a rate below 1 → [`STABLE`](@ref). [`jsr_bound`](@ref)
  returns a rate the solver certified feasible, so that is already a proof of
  stability and needs no margin.

`stall_max = 1` stops at the first lift that buys nothing. Raise it to let a
greedy search cross a plateau, at one bisection per extra step.

!!! warning "Stopping is not a certificate of optimality"
    None of the four says the graph attains the exact joint spectral radius.
    `NOTHING_TO_SPLIT` says this lift has nothing left to separate; a different
    lift, or a template of higher degree, may still do better.

## Choosing the two tolerances

`rtol` is the bisection tolerance of each [`jsr_bound`](@ref) call and `atol` the
one that decides tightness. They have to be read together, `rtol ≪ atol ≪ 1`,
and `atol > rtol` is enforced.

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
    stall_max::Integer = 1,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))
    stall_max > 0 || throw(ArgumentError("stall_max must be positive"))

    # Not cosmetic: at `atol <= rtol` every edge measures tight, because the
    # bisection residual is itself of order `rtol` -- so the test never
    # discriminates and the run ends immediately with no sign that it did not.
    atol > rtol || throw(
        ArgumentError(
            "atol ($atol) must exceed rtol ($rtol), and by orders of magnitude: " *
            "a tight edge measures about the bisection gap, not zero",
        ),
    )

    trace = StabilityCertificate[]
    outcome = DEPTH_EXHAUSTED
    stalled = 0

    for depth in 1:depth_max
        certificate = jsr_bound(template, graph, problem; optimizer, rtol = rtol)

        is_feasible(certificate) || throw(
            ArgumentError(
                "no certificate for $(template) on the graph reached at depth $depth",
            ),
        )

        if !isempty(trace)
            improved = certificate.rate <= last(trace).rate * (1 - rtol)
            stalled = improved ? 0 : stalled + 1
        end

        push!(trace, certificate)

        if until_stability && certificate.rate < 1
            outcome = STABLE
            break
        end

        if stalled >= stall_max
            outcome = STALLED
            break
        end

        depth == depth_max && break

        node = _node_to_split(lift, certificate; atol = atol, rng = rng)

        if node === nothing
            outcome = NOTHING_TO_SPLIT
            break
        end

        graph = lift(graph, node)
    end

    return RefinementTrace(identity.(trace), outcome)
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
