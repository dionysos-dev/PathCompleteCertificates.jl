"""
    RefinementStatus

Why a [`refine`](@ref) run stopped.
"""
@enum RefinementStatus OPTIMAL EXHAUSTED STALLED DEPTH_REACHED STOPPED

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

The strategy proposed no candidate — nothing was left to refine — and the gap
had not closed. With the default strategy and one mode per edge this cannot
happen without [`OPTIMAL`](@ref): no node held at two tight outgoing edges is
Theorem 4's hypothesis. With another strategy it is a genuine outcome, a dead
end that proves nothing.
"""
EXHAUSTED

"""
    STALLED

`stall_max` steps in a row failed to improve the objective.

Worth its own outcome because a graph already attaining the exact joint spectral
radius holds *every* edge tight, so it always looks splittable and would
otherwise be grown forever at a constant bound.
"""
STALLED

"""
    DEPTH_REACHED

`depth_max` certificates were solved with the search still making progress.
"""
DEPTH_REACHED

"""
    STOPPED

The `stop` predicate held on the last certificate — for stability, the rate fell
below `1` when `stop = c -> c.rate < 1`, already a proof.
"""
STOPPED

"""
    RefinementTrace(certificates, steps, status)

One certificate per graph a [`refine`](@ref) run visited, the starting graph's first;
the [`Refined`](@ref) that produced each graph after the start, so a run's steps
can be read back; and a [`RefinementStatus`](@ref).

A certificate carries its own graph and objective, so [`graphs`](@ref) and
`objective` read them off rather than storing them twice.
"""
struct RefinementTrace{C <: AbstractCertificate}
    certificates::Vector{C}
    steps::Vector{Refined}
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

The graphs visited by a [`refine`](@ref) run, the starting graph first.
"""
graphs(trace::RefinementTrace) = [graph(certificate) for certificate in trace.certificates]

"""
    steps(trace)

The [`Refined`](@ref) of each step of a [`refine`](@ref) run: `steps(trace)[k]`
produced `graphs(trace)[k + 1]`, and its [`origins`](@ref) say which node of the
previous graph each node came from.
"""
steps(trace::RefinementTrace) = trace.steps

"""
    rates(trace)

The rate certified on each of [`graphs`](@ref) of a stability run, in the same
order; the matching lower bounds are `jsr_lower_bound.(certificates(trace))`.
"""
rates(trace::RefinementTrace{<:StabilityCertificate}) =
    [certificate.rate for certificate in trace.certificates]

"""
    status(trace::RefinementTrace)

Why the run stopped, as a [`RefinementStatus`](@ref). Only [`OPTIMAL`](@ref)
means the answer is certified.
"""
status(trace::RefinementTrace) = trace.status

"""
    refine(template, problem; optimizer, kwargs...)
    refine(template, graph, problem; optimizer, strategy = SplitTightNode(),
           select = :first, stop = Returns(false), depth_max = 5, stall_max = 1,
           atol = 1e-4, gap_tol = 1e-6, rtol = 1e-6, path_complete = true,
           kwargs...)

Iteratively refine `graph` to tighten the certificate it carries, until the
problem's [`optimality_gap`](@ref) closes or the search runs out.

Without a `graph`, the run starts from [`common_graph`](@ref) of the system: the
one-node graph under arbitrary switching, the automaton itself under
constrained switching.

Each step solves [`best_certificate`](@ref) — [`jsr_bound`](@ref) for
stability — and hands the certificate to `strategy`, any callable
`(certificate; atol) -> Vector{Refined}` returning candidate graphs, best guess
first. The default [`SplitTightNode`](@ref) splits the node held at the most
tight outgoing edges; [`RefineTightEdges`](@ref) tries every local refinement
at every tight edge; [`Hierarchy`](@ref) applies one step to the whole graph.
`select` takes the first candidate, or with `:best` solves every candidate and
keeps the lowest [`objective`](@ref) — one solve per candidate, the rule of
Athanasopoulos & Jungers.

Returns a [`RefinementTrace`](@ref).

## Stopping

- [`optimality_gap`](@ref)` ≤ gap_tol` → [`OPTIMAL`](@ref). Checked *every*
  step, not only when the search runs dry: a graph can be optimal long before
  it is structurally exhausted, and for stability the cycle bracket does not
  depend on `atol` being right;
- `stop(certificate)` → [`STOPPED`](@ref), an explicit request taken before the
  gap; `c -> c.rate < 1` stops a stability run at the first proof of stability;
- `stall_max` steps in a row not improving the objective by more than `rtol`
  → [`STALLED`](@ref). Raise `stall_max` to cross a plateau;
- `depth_max` certificates solved → [`DEPTH_REACHED`](@ref);
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

`path_complete` decides the **starting graph** only: a refinement of a path-complete
graph is path-complete, so the loop asserts rather than re-deciding a
PSPACE-complete question. Other keywords go to [`best_certificate`](@ref).
"""
function refine(template::AbstractTemplate, problem::AbstractProblem; optimizer, kwargs...)
    return refine(template, common_graph(problem.system), problem; optimizer, kwargs...)
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
    gap_tol::Real = 1e-6,
    rtol::Real = 1e-6,
    path_complete::Bool = true,
    kwargs...,
)
    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))
    stall_max > 0 || throw(ArgumentError("stall_max must be positive"))
    select in (:first, :best) || throw(ArgumentError("select must be :first or :best"))

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
    taken = Refined[]
    outcome = DEPTH_REACHED
    stalled = 0

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

        if stop(certificate)
            outcome = STOPPED
            break
        end

        if optimality_gap(certificate; atol) <= gap_tol
            outcome = OPTIMAL
            break
        end

        if stalled >= stall_max
            outcome = STALLED
            break
        end

        depth == depth_max && break

        candidates = strategy(certificate; atol)

        if isempty(candidates)
            outcome = EXHAUSTED
            break
        end

        chosen = first(candidates)

        if select == :best && length(candidates) > 1
            solved = [
                solve(reindex(template, origins(candidate)), graph(candidate), false)
                for candidate in candidates
            ]
            best = argmin(objective.(solved))
            chosen = candidates[best]
            pending = solved[best]
        end

        push!(taken, chosen)
        current = graph(chosen)
        template = reindex(template, origins(chosen))
    end

    return RefinementTrace(identity.(trace), taken, outcome)
end
