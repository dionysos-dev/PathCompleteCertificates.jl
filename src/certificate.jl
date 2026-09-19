"""
    Certificate

What a problem returns: the fitted node functions, together with everything
needed to interpret them.

The three problems used to return three differently shaped named tuples — the
node functions were `V` in one and `P` in the others, `status` appeared in two
of three, and the quality of the answer was `bound`, `eps` or `objective`. This
is the one shape.

`details` carries whatever is specific to the problem, and only that: the
contraction rate for stability, the separation margin and S-procedure
multipliers for safety, the feedback gains and log-determinant objective for
optimal control.

A certificate is **callable**: `certificate(x)` is the common function of
[`common`](@ref) evaluated at `x` — the Lyapunov function, barrier or
value-function bound the graph and templates induce. Reaching for the node
functions individually is rarely what you want.
"""
struct Certificate{P <: AbstractProblem, T <: AbstractTemplate, G, F, D <: NamedTuple, S}
    problem::P
    template::T
    graph::G
    functions::Vector{F}
    status::S
    feasible::Bool
    details::D
end

(certificate::Certificate)(x::AbstractVector{<:Real}) = common(
    certificate.template,
    certificate.graph,
    certificate.problem,
    certificate.functions,
    x,
)

"""
    functions(certificate)

The fitted node function at each node, indexed by node.
"""
functions(certificate::Certificate) = certificate.functions

"""
    is_feasible(certificate) -> Bool

Whether the solve produced a certificate.

`false` means none was found **for this template on this graph** — never that
the property fails. A richer template or a finer graph may well succeed where
this one did not, which is the whole point of having more than one.
"""
is_feasible(certificate::Certificate) = certificate.feasible

"""
    status(certificate)

The solver's termination status, unchanged.

Kept distinct from [`is_feasible`](@ref): a solver can terminate happily on a
model whose solution does not satisfy the conditions when they are re-checked,
and the problems do re-check.
"""
status(certificate::Certificate) = certificate.status

"""
    details(certificate)

The problem-specific part of the result, as a named tuple.

Stability has `rate`; safety has `margin`, `initial_multipliers` and
`unsafe_multipliers`; optimal control has `gains` and `objective`.
"""
details(certificate::Certificate) = certificate.details

function Base.show(io::IO, certificate::Certificate)
    print(
        io,
        "Certificate(",
        nameof(typeof(certificate.problem)),
        ", ",
        nameof(typeof(certificate.template)),
        ", ",
        n_nodes(certificate.graph),
        " nodes, ",
        certificate.feasible ? "feasible" : "infeasible",
        isempty(certificate.details) ? "" : ", $(keys(certificate.details))",
        ")",
    )

    return nothing
end
