# `refine` drives `jsr_bound` and the lifts of `src/lifts/` together, reading
# graph, template and problem at once -- the reason `aggregation.jl` is top-level
# too (Ninite & Jungers, arXiv:2607.00637).
#
# Quadratic and stability because that is what is tested: nothing here reads the
# template except through `edge_slacks`, and the forward lifts are valid for
# every template, so widening is a signature and a test rather than mathematics.

import Random

"""
    RefinementStatus

Why a [`refine`](@ref) run stopped.
"""
@enum RefinementStatus OPTIMAL NOTHING_TO_SPLIT STALLED DEPTH_EXHAUSTED STABLE

"""
    OPTIMAL

The rate is the joint spectral radius, and the run stopped because it had
nothing left to prove. Reached two ways:

- the certified bracket closed — [`jsr_lower_bound`](@ref) came within `gap_tol`
  of the rate. Sound whatever `atol` was;
- [`is_jsr_exact`](@ref) held: every node has at most one tight outgoing edge,
  which is Theorem 4 of Ninite & Jungers.

`rates(trace)[end]` is then the answer, not merely a bound on it.
"""
OPTIMAL

"""
    NOTHING_TO_SPLIT

No node had tight outgoing edges in two different copies of the lift, so no split
could relax anything — and yet [`is_jsr_exact`](@ref) did not hold, so the rate
is not certified.

The two can differ, which is why they are separate outcomes. Theorem 4 counts
tight **edges** per node; the split rule counts the lift's **copies**. Under
[`ForwardLift`](@ref) a node held at two edges to the *same* successor is
unsplittable yet violates the theorem, so the search ends with nothing proved.
[`ForwardEdgeLift`](@ref) — the default — makes the two conditions coincide.
"""
NOTHING_TO_SPLIT

"""
    STALLED

`stall_max` lifts in a row failed to improve the rate.

Distinct from [`NOTHING_TO_SPLIT`](@ref), and that is the point: a graph already
attaining the exact joint spectral radius holds *every* edge tight, so it always
looks splittable and would otherwise be grown forever at a constant bound.
"""
STALLED

"""
    DEPTH_EXHAUSTED

`depth_max` certificates were solved with the search still making progress.
"""
DEPTH_EXHAUSTED

"""
    STABLE

`until_stability` was set and the rate dropped below 1.
"""
STABLE

"""
    RefinementTrace(certificates, status)

One [`StabilityCertificate`](@ref) per graph a [`refine`](@ref) run visited, the
seed's first, and a [`RefinementStatus`](@ref).

A certificate carries its own graph and rate, so [`graphs`](@ref) and
[`rates`](@ref) read them off rather than storing them twice.
"""
struct RefinementTrace{C <: StabilityCertificate}
    certificates::Vector{C}
    status::RefinementStatus
end

"""
    certificates(trace)

The certificate solved on each graph a [`refine`](@ref) run visited — the
Lyapunov functions themselves, so a run can be drawn without re-solving.
"""
certificates(trace::RefinementTrace) = trace.certificates

"""
    graphs(trace)

The graphs visited by a [`refine`](@ref) run, the seed first.
"""
graphs(trace::RefinementTrace) = [graph(certificate) for certificate in trace.certificates]

"""
    rates(trace)

The bound certified on each of [`graphs`](@ref), in the same order.
"""
rates(trace::RefinementTrace) = [certificate.rate for certificate in trace.certificates]

"""
    status(trace::RefinementTrace)

Why the run stopped, as a [`RefinementStatus`](@ref).
"""
status(trace::RefinementTrace) = trace.status

"""
    is_converged(trace) -> Bool

Whether the search ended of its own accord rather than on a budget:
[`OPTIMAL`](@ref), [`NOTHING_TO_SPLIT`](@ref) or [`STALLED`](@ref).

Only the first means the answer is certified. Read [`status`](@ref) whenever
that distinction matters, which is most of the time.
"""
is_converged(trace::RefinementTrace) = status(trace) in (OPTIMAL, NOTHING_TO_SPLIT, STALLED)

"""
    lower_bounds(trace)

A certified **lower** bound on the joint spectral radius at each step, from the
cycles of each certificate's tight subgraph ([`jsr_lower_bound`](@ref)).

Paired with [`rates`](@ref) — the upper bounds — this is the bracket the run
narrowed. Recomputed from the certificates rather than stored, so it cannot
fall out of step with them; pass the same `atol` [`refine`](@ref) ran with.
"""
lower_bounds(trace::RefinementTrace; atol::Real = 1e-4) =
    [jsr_lower_bound(certificate; atol = atol) for certificate in trace.certificates]

"""
    refine(template::QuadraticTemplate, graph, problem::StabilityProblem;
           optimizer, depth_max = 5, until_stability = false,
           lift = ForwardEdgeLift(), atol = 1e-4, atol_max = atol, rtol = 1e-6,
           gap_tol = 1e-6, stall_max = 1, path_complete = true, rng = nothing)

Iteratively lift `graph` to tighten the stability certificate it carries, until
the rate is certified to be the joint spectral radius or the search runs out.

Each step certifies with [`jsr_bound`](@ref) and reads off the active edge
inequalities with [`tight_edges`](@ref). A node whose tight edges fall into two
or more [`copies`](@ref) of `lift` is serving two futures with one function;
splitting it gives each its own. Nodes are scored by how many copies would
receive a tight edge and the best is taken.

Ties go to the **cheapest** split — the node adding fewest copies — and then to
the lowest-numbered one. Node count is the budget the whole comparison with
`de_bruijn` is about, so spending it sparingly is the right preference, and the
rule needs no seed: a run is identical on every machine and Julia version.

Pass an `rng` to break the remaining ties at random instead. Seeding one does
*not* make a run reproducible across Julia versions — `rand(rng, ::Vector)` is
free to sample differently between them.

Counting *copies* rather than edges keeps the rule honest about the lift in hand:
[`ForwardLift`](@ref) cannot separate two edges to the same successor, so a node
held at exactly those is no candidate for it.

Returns a [`RefinementTrace`](@ref).

## Stopping

- the bracket closes, `rate - `[`jsr_lower_bound`](@ref)` ≤ gap_tol`, **or**
  [`is_jsr_exact`](@ref) holds → [`OPTIMAL`](@ref): the rate *is* the joint
  spectral radius;
- no candidate node, and not optimal → [`NOTHING_TO_SPLIT`](@ref);
- `stall_max` lifts in a row not improving the rate by more than `rtol` →
  [`STALLED`](@ref). Raise `stall_max` to cross a plateau, at a bisection a step;
- `depth_max` certificates solved → [`DEPTH_EXHAUSTED`](@ref);
- `until_stability` and a rate below 1 → [`STABLE`](@ref), already a proof. Taken
  before the bracket, being an explicit request to stop early rather than a fact
  about the graph, so a run that could also have certified optimality reports
  `STABLE`.

The bracket is checked *every* step, not only when the search runs dry, and that
is deliberate: the two conditions catch different cases. A graph attaining the
exact rate with every edge tight is never structurally exhausted — Theorem 4
cannot fire — but its bracket closes at once.

## The three tolerances

`rtol` is the bisection tolerance of each [`jsr_bound`](@ref) call, `atol`
decides tightness, `gap_tol` closes the bracket. `atol ≥ 10 rtol` is **enforced**,
and the decade is not decoration: below it the tight subgraph can come out empty,
every node then satisfies [`is_jsr_exact`](@ref) vacuously, and the run certifies
a bound that is not the joint spectral radius.

Bisection stops just *above* the optimum, so an active edge does not measure
zero — it measures about the bisection gap. On a rotation-and-shear pair over
`de_bruijn(1, 2)` at `rtol = 1e-6` the three active edges measure `1.3e-7`,
`6.0e-7` and `2.9e-6` against `0.17` for the slack one. Lower `atol` towards
`rtol` and active edges are missed; raise it and slack edges are called tight.

Only `atol` is delicate, and [`jsr_lower_bound`](@ref) is why it need not be
fatal: a cycle of the tight subgraph bounds the joint spectral radius whatever
`atol` was, so a badly chosen one weakens the bracket without making
[`OPTIMAL`](@ref) wrong. [`is_jsr_exact`](@ref) has no such protection, which is
the argument for reading `lower_bounds(trace)` rather than trusting the
structural test alone.

### Escalating it

`atol_max` is the safeguard, and it is **off by default**, `atol_max == atol`
meaning never escalate. With the decade above enforced it should not be needed:
an active edge measures a few times `rtol`, so `atol` clears it. It guards the
case the ratio cannot — a solution whose accuracy is worse than `rtol` suggests,
which an ill-conditioned model can produce.

Set it higher and a dead end is no longer taken at face value: before concluding
anything, the tolerance is multiplied by ten — up to `atol_max` — and the same
certificate re-read. An edge that is active in truth but not numerically then
appears, and the search continues. Nothing is re-solved and nothing restarted,
because the tolerance decides how a solution is *read*, not what it is; the
raised value carries to later steps, the bisection residual being of one scale
throughout.

This is the diagnostic for the one case the bracket cannot settle. Reaching a
dead end means the bracket did *not* close, so [`is_jsr_exact`](@ref) holding
there says the structure claims exactness while the cycles disagree — either
`atol` was too small, or the joint spectral radius is attained by no cycle the
search found. If escalating makes the dead end go away, it was the first.

`path_complete` decides the **seed** only: a lift of a path-complete graph is
path-complete, so the loop asserts rather than re-deciding a PSPACE-complete
question. Set it `false` to assert the seed too.
"""
function refine(
    template::QuadraticTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    depth_max::Integer = 5,
    until_stability::Bool = false,
    lift::AbstractLift = ForwardEdgeLift(),
    atol::Real = 1e-4,
    atol_max::Real = atol,
    rtol::Real = 1e-6,
    gap_tol::Real = 1e-6,
    stall_max::Integer = 1,
    path_complete::Bool = true,
    rng::Union{Nothing, Random.AbstractRNG} = nothing,
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))
    stall_max > 0 || throw(ArgumentError("stall_max must be positive"))

    atol_max >= atol ||
        throw(ArgumentError("atol_max ($atol_max) must be at least atol ($atol)"))

    # An active edge measures about the bisection residual, so `atol` has to clear
    # it with room. Measured at `rtol = 1e-6`, active slacks run to 3.5e-6 -- 3.5x
    # -- so a decade of margin is the least that discriminates. This used to
    # require only `atol > rtol` while the message promised orders of magnitude,
    # and at 2x the tight subgraph came out EMPTY: every node then satisfies
    # Theorem 4 vacuously and `refine` certified the seed's bound as the JSR.
    atol >= 10 * rtol || throw(
        ArgumentError(
            "atol ($atol) must exceed rtol ($rtol) by at least a decade: a tight " *
            "edge measures about the bisection gap, not zero, so a smaller " *
            "margin cannot tell an active edge from a slack one",
        ),
    )

    trace = StabilityCertificate[]
    outcome = DEPTH_EXHAUSTED
    stalled = 0
    tolerance = atol

    for depth in 1:depth_max
        certificate = jsr_bound(
            template,
            graph,
            problem;
            optimizer,
            rtol = rtol,
            path_complete = path_complete && depth == 1,
        )

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

        # First, because it is an explicit request to stop early rather than a
        # fact about the graph -- and it spares the cycle search below.
        if until_stability && certificate.rate < 1
            outcome = STABLE
            break
        end

        # Checked every step, because a graph can be optimal long before it is
        # structurally exhausted -- and the bracket, unlike `is_jsr_exact`, does
        # not depend on `atol` being right.
        if certificate.rate - jsr_lower_bound(certificate; atol = tolerance) <= gap_tol
            outcome = OPTIMAL
            break
        end

        if stalled >= stall_max
            outcome = STALLED
            break
        end

        depth == depth_max && break

        node = _node_to_split(lift, certificate; atol = tolerance, rng = rng)

        # A dead end may only mean the tight subgraph is too thin: an active edge
        # measures about the bisection residual, not zero, so too small a
        # tolerance hides it. Re-read the SAME solution at a coarser one before
        # concluding anything -- no restart and no second solve, because the
        # tolerance changes how a certificate is read, not the certificate.
        while node === nothing && 10 * tolerance <= atol_max
            tolerance *= 10
            node = _node_to_split(lift, certificate; atol = tolerance, rng = rng)
        end

        if node === nothing
            # Theorem 4 counts tight edges per node; the split rule counts the
            # lift's copies. They coincide under `ForwardEdgeLift` and not under
            # `ForwardLift`, so having nothing to split is not on its own a proof.
            outcome =
                is_jsr_exact(certificate; atol = tolerance) ? OPTIMAL : NOTHING_TO_SPLIT
            break
        end

        graph = lift(graph, node)
    end

    return RefinementTrace(identity.(trace), outcome)
end

"""
    _node_to_split(lift, certificate; atol, rng)

The node `lift` should be applied to next, or `nothing` when there is none.

A node scores the number of `lift`'s [`copies`](@ref) that would receive a tight
edge; below two, every tight edge stays together and the split frees nothing. No
graph is built to decide it.
"""
function _node_to_split(
    lift::AbstractLift,
    certificate::StabilityCertificate;
    atol::Real,
    rng::Union{Nothing, Random.AbstractRNG},
)
    graph_ = graph(certificate)
    tight = Set(tight_edges(certificate; atol = atol))

    separated = zeros(Int, n_nodes(graph_))
    cost = zeros(Int, n_nodes(graph_))

    for node in nodes(graph_)
        groups = copies(lift, graph_, node)
        cost[node] = length(groups)

        for group in groups
            any(edge -> (node, dest(edge), label(graph_, edge)) in tight, group) &&
                (separated[node] += 1)
        end
    end

    best = maximum(separated)
    best > 1 || return nothing

    # Among equally-held nodes, split the cheapest: `cost` is how many nodes the
    # graph gains, and node count is the budget the whole comparison is about.
    candidates = [node for node in nodes(graph_) if separated[node] == best]
    cheapest = minimum(cost[node] for node in candidates)
    filter!(node -> cost[node] == cheapest, candidates)

    # Deterministic by default, and not merely seeded: `rand(rng, ::Vector)` is
    # not guaranteed to pick the same element across Julia versions, so a seed
    # reproduces a run on one version and silently changes it on the next.
    return rng === nothing ? first(candidates) : rand(rng, candidates)
end
