# `refine` drives a problem's driver and the lifts of `src/lifts/` together,
# reading graph, template and problem at once -- the reason `aggregation.jl`
# is top-level too. It names no problem: what it needs from one is
# `best_certificate`, `objective`, `edge_slacks` and `optimality_gap`, and the
# strategy that picks where to lift is any callable (Ninite & Jungers,
# arXiv:2607.00637; Athanasopoulos & Jungers, CDC 2019).

"""
    RefinementStatus

Why a [`refine`](@ref) run stopped.
"""
@enum RefinementStatus OPTIMAL EXHAUSTED STALLED DEPTH_EXHAUSTED STOPPED

"""
    OPTIMAL

The [`optimality_gap`](@ref) closed: the certificate is proved as good as any
graph could make it, and the run stopped because it had nothing left to prove.
For stability, `rates(trace)[end]` is then the joint spectral radius, not merely
a bound on it — reached either by the cycle bracket of
[`jsr_lower_bound`](@ref), sound whatever `atol` was, or by
[`is_jsr_exact`](@ref), Theorem 4 of Ninite & Jungers.
"""
OPTIMAL

"""
    EXHAUSTED

The strategy proposed no candidate — nothing was left to lift — and the gap
had not closed. With the default strategy and a letter graph this cannot
happen without [`OPTIMAL`](@ref): no node held at two tight outgoing edges is
Theorem 4's hypothesis. With another strategy it is a genuine outcome, a dead
end that proves nothing.
"""
EXHAUSTED

"""
    STALLED

`stall_max` lifts in a row failed to improve the objective.

Worth its own outcome because a graph already attaining the exact joint spectral
radius holds *every* edge tight, so it always looks splittable and would
otherwise be grown forever at a constant bound.
"""
STALLED

"""
    DEPTH_EXHAUSTED

`depth_max` certificates were solved with the search still making progress.
"""
DEPTH_EXHAUSTED

"""
    STOPPED

The `stop` predicate held on the last certificate — for stability, the rate fell
below `1` when `stop = c -> c.rate < 1`, already a proof.
"""
STOPPED

"""
    RefinementTrace(certificates, steps, status)

One certificate per graph a [`refine`](@ref) run visited, the seed's first;
the [`Lifted`](@ref) that produced each graph after the seed, so a run's lifts
can be read back; and a [`RefinementStatus`](@ref).

A certificate carries its own graph and objective, so [`graphs`](@ref) and
[`objectives`](@ref) read them off rather than storing them twice.
"""
struct RefinementTrace{C <: AbstractCertificate}
    certificates::Vector{C}
    steps::Vector{Lifted}
    status::RefinementStatus
end

"""
    certificates(trace)

The certificate solved on each graph a [`refine`](@ref) run visited — the node
functions themselves, so a run can be drawn without re-solving.
"""
certificates(trace::RefinementTrace) = trace.certificates

"""
    graphs(trace)

The graphs visited by a [`refine`](@ref) run, the seed first.
"""
graphs(trace::RefinementTrace) = [graph(certificate) for certificate in trace.certificates]

"""
    steps(trace)

The [`Lifted`](@ref) of each step of a [`refine`](@ref) run: `steps(trace)[k]`
produced `graphs(trace)[k + 1]`, and its [`origins`](@ref) say which node of the
previous graph each node came from.
"""
steps(trace::RefinementTrace) = trace.steps

"""
    objectives(trace)

The [`objective`](@ref) of the certificate on each of [`graphs`](@ref), in the
same order.
"""
objectives(trace::RefinementTrace) =
    [objective(certificate) for certificate in trace.certificates]

"""
    rates(trace)

The rate certified on each of [`graphs`](@ref) of a stability run, in the same
order. [`objectives`](@ref) is the same for any problem.
"""
rates(trace::RefinementTrace{<:StabilityCertificate}) =
    [certificate.rate for certificate in trace.certificates]

"""
    status(trace::RefinementTrace)

Why the run stopped, as a [`RefinementStatus`](@ref).
"""
status(trace::RefinementTrace) = trace.status

"""
    is_converged(trace) -> Bool

Whether the search ended of its own accord rather than on a budget or a
request: [`OPTIMAL`](@ref), [`STALLED`](@ref) or [`EXHAUSTED`](@ref).

Only the first means the answer is certified. Read [`status`](@ref) whenever
that distinction matters, which is most of the time.
"""
is_converged(trace::RefinementTrace) = status(trace) in (OPTIMAL, STALLED, EXHAUSTED)

"""
    lower_bounds(trace)

A certified **lower** bound on the joint spectral radius at each step of a
stability run, from the cycles of each certificate's tight subgraph
([`jsr_lower_bound`](@ref)).

Paired with [`rates`](@ref) — the upper bounds — this is the bracket the run
narrowed. Recomputed from the certificates rather than stored, so it cannot
fall out of step with them; pass the same `atol` [`refine`](@ref) ran with.
"""
lower_bounds(trace::RefinementTrace{<:StabilityCertificate}; atol::Real = 1e-4) =
    [jsr_lower_bound(certificate; atol = atol) for certificate in trace.certificates]

"""
    refine(template, problem; optimizer, kwargs...)
    refine(template, graph, problem; optimizer, strategy = SplitTightNode(),
           select = :first, stop = Returns(false), depth_max = 5, stall_max = 1,
           atol = 1e-4, atol_max = atol, gap_tol = 1e-6, rtol = 1e-6,
           path_complete = true, kwargs...)

Iteratively lift `graph` to tighten the certificate it carries, until the
problem's [`optimality_gap`](@ref) closes or the search runs out.

Without a `graph`, the run starts from [`seed`](@ref) of the system: the
one-node graph under arbitrary switching, the automaton itself under
constrained switching.

Each step solves [`best_certificate`](@ref) — [`jsr_bound`](@ref) for
stability — and hands the certificate to `strategy`, any callable
`(certificate; atol) -> Vector{Lifted}` returning candidate graphs, best guess
first. The default [`SplitTightNode`](@ref) splits the node held at the most
tight outgoing edges; [`LiftTightEdges`](@ref) tries every local lift at every
tight edge; [`Hierarchy`](@ref) applies one global lift. `select` takes the
first candidate, or with `:best` solves every candidate and keeps the lowest
[`objective`](@ref) — one solve per candidate, the rule of Athanasopoulos &
Jungers.

Returns a [`RefinementTrace`](@ref).

## Stopping

- [`optimality_gap`](@ref)` ≤ gap_tol` → [`OPTIMAL`](@ref). Checked *every*
  step, not only when the search runs dry: a graph can be optimal long before
  it is structurally exhausted, and for stability the cycle bracket does not
  depend on `atol` being right;
- `stop(certificate)` → [`STOPPED`](@ref), an explicit request taken before the
  gap; `c -> c.rate < 1` stops a stability run at the first proof of stability;
- `stall_max` lifts in a row not improving the objective by more than `rtol`
  → [`STALLED`](@ref). Raise `stall_max` to cross a plateau;
- `depth_max` certificates solved → [`DEPTH_EXHAUSTED`](@ref);
- no candidate → [`EXHAUSTED`](@ref). With the default strategy on a letter
  graph this coincides with `OPTIMAL`, since "no node holds two tight outgoing
  edges" is Theorem 4's hypothesis, and the gap is tested first.

## The tolerances

`rtol` is the solve tolerance forwarded to [`best_certificate`](@ref) — the
bisection tolerance of each [`jsr_bound`](@ref) call — and `atol` decides
tightness. `atol ≥ 10 rtol` is **enforced**: bisection stops just *above* the
optimum, so an active edge measures about the bisection gap, not zero. On a
rotation-and-shear pair over `de_bruijn(1, 2)` at `rtol = 1e-6` the three active
edges measure `1.3e-7`, `6.0e-7` and `2.9e-6` against `0.17` for the slack one.
Below a decade the tight subgraph can come out empty, every node then satisfies
[`is_jsr_exact`](@ref) vacuously, and the run certifies a bound that is not the
joint spectral radius.

`atol_max` is the safeguard, **off by default** (`atol_max == atol`). Set it
higher and a dead end is not taken at face value: the tolerance is multiplied
by ten, up to the ceiling, and the same certificate re-read. Nothing is
re-solved, because the tolerance decides how a solution is *read*, not what it
is. Its remaining purpose is a solution whose accuracy is worse than `rtol`
suggests.

`path_complete` decides the **seed** only: a lift of a path-complete graph is
path-complete, so the loop asserts rather than re-deciding a PSPACE-complete
question. Other keywords go to [`best_certificate`](@ref).
"""
function refine(template::AbstractTemplate, problem::AbstractProblem; optimizer, kwargs...)
    return refine(template, seed(problem.system), problem; optimizer, kwargs...)
end

function refine(
    template::AbstractTemplate,
    start::CertificateGraph,
    problem::AbstractProblem;
    optimizer,
    strategy = SplitTightNode(),
    select::Symbol = :first,
    stop = Returns(false),
    depth_max::Integer = 5,
    stall_max::Integer = 1,
    atol::Real = 1e-4,
    atol_max::Real = atol,
    gap_tol::Real = 1e-6,
    rtol::Real = 1e-6,
    path_complete::Bool = true,
    kwargs...,
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))
    stall_max > 0 || throw(ArgumentError("stall_max must be positive"))
    select in (:first, :best) || throw(ArgumentError("select must be :first or :best"))

    atol_max >= atol ||
        throw(ArgumentError("atol_max ($atol_max) must be at least atol ($atol)"))

    # An active edge measures about the bisection residual, so `atol` has to clear
    # it with room: measured at `rtol = 1e-6`, active slacks run to 3.5e-6, and a
    # decade is the least that discriminates. At 2x the tight subgraph comes out
    # EMPTY, every node then satisfies Theorem 4 vacuously, and the seed's own
    # bound gets certified as the JSR -- which is why this is an error, not advice.
    atol >= 10 * rtol || throw(
        ArgumentError(
            "atol ($atol) must exceed rtol ($rtol) by at least a decade: a tight " *
            "edge measures about the bisection gap, not zero, so a smaller " *
            "margin cannot tell an active edge from a slack one",
        ),
    )

    solve(tmpl, g, first_step) = best_certificate(
        tmpl,
        g,
        problem;
        optimizer,
        rtol = rtol,
        path_complete = path_complete && first_step,
        kwargs...,
    )

    trace = AbstractCertificate[]
    lifts = Lifted[]
    outcome = DEPTH_EXHAUSTED
    stalled = 0
    tolerance = atol

    # `:best` solves the candidates before choosing, so the chosen one's
    # certificate is already in hand when the next step begins.
    pending = nothing
    current = start

    for depth in 1:depth_max
        certificate = pending === nothing ? solve(template, current, depth == 1) : pending
        pending = nothing

        is_feasible(certificate) || throw(
            ArgumentError(
                "no certificate for $(template) on the graph reached at depth $depth",
            ),
        )

        if !isempty(trace)
            previous = objective(last(trace))
            improved = objective(certificate) <= previous - rtol * abs(previous)
            stalled = improved ? 0 : stalled + 1
        end

        push!(trace, certificate)

        # First, because it is an explicit request to stop early rather than a
        # fact about the graph -- and it spares the gap below.
        if stop(certificate)
            outcome = STOPPED
            break
        end

        if optimality_gap(certificate; atol = tolerance) <= gap_tol
            outcome = OPTIMAL
            break
        end

        if stalled >= stall_max
            outcome = STALLED
            break
        end

        depth == depth_max && break

        candidates = strategy(certificate; atol = tolerance)

        # A dead end may only mean the tight subgraph is too thin: an active edge
        # measures about the bisection residual, not zero, so too small a
        # tolerance hides it. Re-read the SAME solution at a coarser one before
        # concluding anything -- no restart and no second solve.
        while isempty(candidates) && 10 * tolerance <= atol_max
            tolerance *= 10
            candidates = strategy(certificate; atol = tolerance)
        end

        if isempty(candidates)
            outcome = EXHAUSTED
            break
        end

        chosen = first(candidates)

        if select == :best && length(candidates) > 1
            # Each candidate is solved with the template moved onto its graph.
            solved = [
                solve(reindex(template, origins(candidate)), graph(candidate), false)
                for candidate in candidates
            ]
            best = argmin(objective.(solved))
            chosen = candidates[best]
            pending = solved[best]
        end

        push!(lifts, chosen)
        current = graph(chosen)
        template = reindex(template, origins(chosen))
    end

    return RefinementTrace(identity.(trace), lifts, outcome)
end
