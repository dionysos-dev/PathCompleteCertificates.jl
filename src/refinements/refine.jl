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

The algorithm had no next graph before the gap closed.
"""
EXHAUSTED

"""
    STALLED

`stall_max` steps in a row did not improve the objective.
"""
STALLED

"""
    DEPTH_REACHED

The run visited `depth_max` graphs, its limit.
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
[`Lifted`](@ref) step that produced each graph after the first, and a
[`RefinementStatus`](@ref).
"""
struct RefinementTrace{C <: AbstractCertificate}
    certificates::Vector{C}
    steps::Vector{Lifted}
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

The [`Lifted`](@ref) graph of each step: `steps(trace)[k]` produced
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
    refine(template, graph, problem; optimizer, algorithm = TightestNodeSplitting(),
           stop = Returns(false), depth_max = 5, stall_max = 1, atol = 1e-4,
           gap_tol = 1e-6, rtol = 1e-6, check_path_complete = true, kwargs...)

Refine `graph`, by default [`initial_graph`](@ref)`(algorithm, system)`, until
the [`optimality_gap`](@ref) of its certificate closes; returns a
[`RefinementTrace`](@ref). At each step [`next_graph`](@ref) of `algorithm`
gives the next graph, a lift of the current one.

- The run stops when `stop(certificate)` holds, the gap is at most `gap_tol`,
  `stall_max` steps in a row fail to improve the objective by `rtol`,
  `depth_max` graphs are visited, or no candidate is left.
- `rtol` is the bisection tolerance on the rate, `atol` the tightness
  threshold on the slacks, with `atol ≥ 10 rtol`.
- `check_path_complete = false` skips the path-completeness check of the starting
  graph.

Other keywords go to [`best_certificate`](@ref).
"""
function refine(
    template::AbstractTemplate,
    problem::AbstractProblem;
    optimizer,
    algorithm::AbstractRefinementAlgorithm = TightestNodeSplitting(),
    kwargs...,
)
    start = initial_graph(algorithm, problem.system)
    return refine(template, start, problem; optimizer, algorithm, kwargs...)
end

function refine(
    template::AbstractTemplate,
    start::CertificateGraph,
    problem::AbstractProblem;
    optimizer,
    algorithm::AbstractRefinementAlgorithm = TightestNodeSplitting(),
    stop = Returns(false),
    depth_max::Integer = 5,
    stall_max::Integer = 1,
    atol::Real = _TIGHT_ATOL,
    gap_tol::Real = 1e-6,
    rtol::Real = 1e-6,
    check_path_complete::Bool = true,
    kwargs...,
)
    _refinable(problem) || throw(
        ArgumentError(
            "refine reads the objective and the edge slacks of a certificate, " *
            "which $(nameof(typeof(problem))) does not define",
        ),
    )

    depth_max > 0 || throw(ArgumentError("depth_max must be positive"))
    stall_max > 0 || throw(ArgumentError("stall_max must be positive"))

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
        check_path_complete = check_path_complete && first_step,
        kwargs...,
    )

    trace = AbstractCertificate[]
    taken = Lifted[]
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

        # A candidate is solved with the template following its origins.
        solve_lifted = let template = template
            lifted -> solve(reindex(template, origins(lifted)), graph(lifted), false)
        end
        result = next_graph(algorithm, certificate; atol, solve = solve_lifted)

        if result === nothing
            outcome = EXHAUSTED
            break
        end

        chosen, pending = result

        push!(taken, chosen)
        current = graph(chosen)
        template = reindex(template, origins(chosen))
    end

    return RefinementTrace(identity.(trace), taken, outcome)
end
