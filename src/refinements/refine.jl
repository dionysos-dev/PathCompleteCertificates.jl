"""
    RefinementStatus

Why a [`refine`](@ref) run stopped.
"""
@enum RefinementStatus OPTIMAL EXHAUSTED STALLED DEPTH_REACHED STOPPED

"""
    OPTIMAL

The [`optimality_gap`](@ref) closed; for stability, the last rate is the joint
spectral radius.
"""
OPTIMAL

"""
    EXHAUSTED

The strategy proposed no candidate before the gap closed.
"""
EXHAUSTED

"""
    STALLED

`stall_max` steps in a row did not improve the objective.
"""
STALLED

"""
    DEPTH_REACHED

`depth_max` certificates were solved.
"""
DEPTH_REACHED

"""
    STOPPED

The `stop` predicate held on the last certificate.
"""
STOPPED

"""
    RefinementTrace(certificates, steps, status)

The certificates of a [`refine`](@ref) run, one per graph visited, the
[`Refined`](@ref) step that produced each graph after the first, and a
[`RefinementStatus`](@ref).
"""
struct RefinementTrace{C <: AbstractCertificate}
    certificates::Vector{C}
    steps::Vector{Refined}
    status::RefinementStatus
end

"""
    certificates(trace)

The certificate solved on each graph a [`refine`](@ref) run visited.
"""
certificates(trace::RefinementTrace) = trace.certificates

"""
    graphs(trace)

The graphs visited by a [`refine`](@ref) run, the starting graph first.
"""
graphs(trace::RefinementTrace) = [graph(certificate) for certificate in trace.certificates]

"""
    steps(trace)

The [`Refined`](@ref) of each step: `steps(trace)[k]` produced
`graphs(trace)[k + 1]`.
"""
steps(trace::RefinementTrace) = trace.steps

"""
    rates(trace)

The rate certified on each of [`graphs`](@ref) of a stability run.
"""
rates(trace::RefinementTrace{<:StabilityCertificate}) =
    [certificate.rate for certificate in trace.certificates]

"""
    status(trace::RefinementTrace)

Why the run stopped, as a [`RefinementStatus`](@ref).
"""
status(trace::RefinementTrace) = trace.status

"""
    refine(template, problem; optimizer, kwargs...)
    refine(template, graph, problem; optimizer, strategy = SplitTightNode(),
           select = :first, stop = Returns(false), depth_max = 5, stall_max = 1,
           atol = 1e-4, gap_tol = 1e-6, rtol = 1e-6, path_complete = true,
           kwargs...)

Refine `graph`, by default [`common_graph`](@ref) of the system, until the
[`optimality_gap`](@ref) of its certificate closes; returns a
[`RefinementTrace`](@ref).

- `strategy(certificate; atol)` returns candidate [`Refined`](@ref) graphs,
  best first.
- `select = :best` solves every candidate and keeps the lowest
  [`objective`](@ref); `:first` takes the first.
- The run stops when `stop(certificate)` holds, the gap is at most `gap_tol`,
  `stall_max` steps in a row fail to improve the objective by `rtol`,
  `depth_max` certificates are solved, or no candidate is left.
- `rtol` is the solve tolerance and `atol` decides tightness, with
  `atol ≥ 10 rtol`.
- `path_complete = false` skips the path-completeness check of the starting
  graph.

Other keywords go to [`best_certificate`](@ref).
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
