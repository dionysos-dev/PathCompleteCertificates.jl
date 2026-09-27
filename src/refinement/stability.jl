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
@enum RefinementStatus NOTHING_TO_SPLIT STALLED DEPTH_EXHAUSTED STABLE

"""
    NOTHING_TO_SPLIT

No node had tight outgoing edges in two different copies of the lift, so no split
could relax anything.
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

Whether the search ended with this lift having nothing left to give:
[`NOTHING_TO_SPLIT`](@ref) or [`STALLED`](@ref). Read [`status`](@ref) when the
difference matters.
"""
is_converged(trace::RefinementTrace) = status(trace) in (NOTHING_TO_SPLIT, STALLED)

"""
    refine(template::QuadraticTemplate, graph, problem::StabilityProblem;
           optimizer, depth_max = 5, until_stability = false,
           lift = ForwardLift(), atol = 1e-4, rtol = 1e-6, stall_max = 1,
           path_complete = true, rng = nothing)

Iteratively lift `graph` to tighten the stability certificate it carries.

Each step certifies with [`jsr_bound`](@ref) and reads off the active edge
inequalities with [`tight_edges`](@ref). A node whose tight edges fall into two
or more [`copies`](@ref) of `lift` is serving two futures with one function;
splitting it gives each its own. Nodes are scored by how many copies would
receive a tight edge and the best is taken.

Ties go to the lowest-numbered node, so a run is reproducible across machines and
Julia versions. Pass an `rng` to break them at random instead — but note that
seeding one does *not* make a run reproducible across Julia versions, because
`rand(rng, ::Vector)` is free to sample differently between them.

Counting *copies* rather than edges keeps the rule honest about the lift in hand:
[`ForwardLift`](@ref) cannot separate two edges to the same successor, so a node
held at exactly those is no candidate for it.

Returns a [`RefinementTrace`](@ref).

## Stopping

- no candidate node → [`NOTHING_TO_SPLIT`](@ref);
- `stall_max` lifts in a row not improving the rate by more than `rtol` →
  [`STALLED`](@ref). Raise `stall_max` to cross a plateau, at a bisection a step;
- `depth_max` certificates solved → [`DEPTH_EXHAUSTED`](@ref);
- `until_stability` and a rate below 1 → [`STABLE`](@ref), already a proof.

None of the four says the graph attains the exact joint spectral radius; a
different lift or a richer template may still do better.

## The two tolerances

`rtol` is the bisection tolerance of each [`jsr_bound`](@ref) call, `atol`
decides tightness, and they must satisfy `rtol ≪ atol ≪ 1`, which is enforced.

Bisection stops just *above* the optimum, so an active edge does not measure
zero — it measures about the bisection gap. On a rotation-and-shear pair over
`de_bruijn(1, 2)` at `rtol = 1e-6` the three active edges measure `1.3e-7`,
`6.0e-7` and `2.9e-6` against `0.17` for the slack one. Lower `atol` towards
`rtol` and active edges are missed; raise it and slack edges are called tight.

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
    lift::AbstractLift = ForwardLift(),
    atol::Real = 1e-4,
    rtol::Real = 1e-6,
    stall_max::Integer = 1,
    path_complete::Bool = true,
    rng::Union{Nothing, Random.AbstractRNG} = nothing,
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))
    stall_max > 0 || throw(ArgumentError("stall_max must be positive"))

    # At `atol <= rtol` the bisection residual alone makes every edge look tight,
    # so the test never discriminates and the run ends on the first step.
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
