"""
    StabilityProblem(system)

Stability problem for an input-free switched linear system.

The problem stores the system only; the rate is given to [`certify`](@ref) or
bisected on by [`jsr_bound`](@ref).
"""
struct StabilityProblem{S} <: AbstractProblem
    system::S

    function StabilityProblem(system::S) where {S}
        has_input(system) &&
            throw(ArgumentError("StabilityProblem requires an input-free system"))

        return new{S}(system)
    end
end

dual(problem::StabilityProblem) = StabilityProblem(dual(problem.system))

"""
    StabilityCertificate

A path-complete Lyapunov function and the contraction rate it certifies.

`rate` is an **upper** bound on the joint spectral radius: every switching
sequence contracts at least this fast under the node functions. It is the
smallest rate the bisection in [`jsr_bound`](@ref) could certify with this
template on this graph, so a larger value says the template is conservative,
not that the system is slower.

`functions(certificate)` are the node Lyapunov functions and `certificate(x)`
the common one.
"""
struct StabilityCertificate{D <: CertificateData, T <: Real} <: AbstractCertificate
    data::D
    rate::T
end

# One method, generic over templates: the whole edge condition of this problem
# is the template's domination primitive at the scale the driver passes, so a
# new template needs nothing here.
function add_edge_constraint!(
    model::JuMP.Model,
    ::StabilityProblem,
    template::AbstractTemplate,
    V_src,
    V_dst,
    A::AbstractMatrix;
    scale::Real = 1,
)
    add_domination!(model, template, V_src, V_dst, A; scale)

    return nothing
end

"""
    optimization_model(template, graph, problem; optimizer, rate = 1)

The feasibility problem of the Lyapunov inequalities

    V_b(A_w x) <= rate^(d |w|) * V_a(x)

for every edge `(a, b, w)` of `graph`, `d` the template's degree of homogeneity
and `|w|` the number of modes the edge reads — one on a letter graph, the
product of the modes along the word on a [`WordGraph`](@ref).

The model has no objective: [`certify`](@ref) solves it once at a rate and
[`jsr_bound`](@ref) bisects on the rate. `optimizer` must be an LP solver for
the copositive and polyhedral templates and an SDP solver for the quadratic
one.
"""
function optimization_model(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::StabilityProblem;
    optimizer,
    rate::Real = 1,
    path_complete::Bool = true,
)
    rate >= 0 || throw(ArgumentError("the rate must be nonnegative"))

    A = mode_matrices(problem.system)

    _check_stability_data(template, graph, problem; path_complete = path_complete)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    dimension = size(first(A), 1)

    Vs = [add_function_variables!(model, template, dimension, a) for a in nodes(graph)]

    for V in Vs
        add_nonnegativity!(model, template, V)
        add_normalization!(model, template, V)
    end

    degree = homogeneity_degree(template)

    for edge in edges(graph)
        word = letters(label(graph, edge))

        add_edge_constraint!(
            model,
            problem,
            template,
            Vs[source(edge)],
            Vs[dest(edge)],
            _product(A, word);
            scale = rate^(degree * length(word)),
        )
    end

    model[:stability_V] = Vs

    return model
end

"""
    jsr_bound(template, graph, problem; optimizer, rtol = 1e-3,
              max_iterations = 100, initial_upper = 1.0)

Estimate an upper bound on the joint spectral radius by bisection.

At each candidate rate, solve the fixed-rate feasibility problem.

Returns a [`StabilityCertificate`](@ref). Its `rate` is the smallest feasible
bound found to relative tolerance `rtol`; `functions(certificate)` are the
node Lyapunov functions, and `certificate(x)` evaluates the common one.
"""
function jsr_bound(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::StabilityProblem;
    optimizer,
    rtol::Real = 1e-3,
    max_iterations::Integer = 100,
    initial_upper::Real = 1.0,
    path_complete::Bool = true,
)
    rtol > 0 || throw(ArgumentError("rtol must be positive"))

    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive"))

    initial_upper > 0 || throw(ArgumentError("initial_upper must be positive"))

    # Once, here. The bisection below builds a model per step and each build
    # revalidates, so leaving this on would run a PSPACE-complete test a dozen
    # times over on a graph that cannot have changed.
    _check_stability_data(template, graph, problem; path_complete = path_complete)

    function feasible(rate)
        model = optimization_model(
            template,
            graph,
            problem;
            optimizer,
            rate,
            path_complete = false,
        )
        JuMP.optimize!(model)
        return JuMP.termination_status(model) in _FEASIBLE_TERMINATION_STATUSES
    end

    lower = zero(initial_upper)
    upper = initial_upper

    while !feasible(upper)
        upper *= 2

        isfinite(upper) ||
            throw(ArgumentError("could not find a finite feasible upper bound"))
    end

    for _ in 1:max_iterations
        upper - lower <= rtol * upper && break

        candidate = (lower + upper) / 2

        if feasible(candidate)
            upper = candidate
        else
            lower = candidate
        end
    end

    certificate = certify(
        template,
        graph,
        problem;
        optimizer = optimizer,
        rate = upper,
        path_complete = false,
    )

    is_feasible(certificate) ||
        throw(ArgumentError("the final stability problem is not feasible"))

    return certificate
end

"""
    certify(template, graph, problem::StabilityProblem; optimizer, rate = 1)

Solve the fixed-`rate` Lyapunov feasibility problem once; `is_feasible` of the
result says whether the system contracts at that rate on this graph in this
template. [`jsr_bound`](@ref) bisects on `rate` on top of it.
"""
function certify(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::StabilityProblem;
    optimizer,
    rate::Real = 1,
    path_complete::Bool = true,
)
    model = optimization_model(template, graph, problem; optimizer, rate, path_complete)

    JuMP.optimize!(model)
    status = JuMP.termination_status(model)

    status in _FEASIBLE_TERMINATION_STATUSES ||
        return StabilityCertificate(_failed(problem, template, graph, status), rate)

    V = [solution_value(template, v) for v in model[:stability_V]]

    return StabilityCertificate(
        CertificateData(problem, template, graph, V, status, true),
        rate,
    )
end

"""
    dual(certificate::StabilityCertificate)

The certificate on `dual(graph)` for `dual(problem)` in `dual(template)` made of
the dual norms of the node functions, at the same rate (Debauche, Lemma 6.25).

Each edge inequality `V_d(A_i x) ≤ γ V_s(x)` is, by duality of norms,
`V_s*(A_iᵀ x) ≤ γ V_d*(x)`: the inequality of the reversed edge. Nothing is
solved, and an edge of the result is tight exactly when its reverse was. An
infeasible certificate dualises to an infeasible one with the same status.

Requires a template that [`has_dual`](@ref).
"""
function dual(certificate::StabilityCertificate)
    template_ = template(certificate)
    dual_problem = dual(problem(certificate))
    dual_template = dual(template_)
    dual_graph = dual(graph(certificate))

    is_feasible(certificate) || return StabilityCertificate(
        _failed(dual_problem, dual_template, dual_graph, status(certificate)),
        certificate.rate,
    )

    V = [dual(template_, v) for v in functions(certificate)]

    return StabilityCertificate(
        CertificateData(
            dual_problem,
            dual_template,
            dual_graph,
            V,
            status(certificate),
            true,
        ),
        certificate.rate,
    )
end

function _check_stability_data(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::StabilityProblem;
    path_complete::Bool = true,
)
    _check_modes(graph, problem.system; path_complete = path_complete)
    check_dynamics(template, mode_matrices(problem.system))

    return nothing
end

# --- What refine reads: the driver, the objective and the optimality gap ------

function best_certificate(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::StabilityProblem;
    optimizer,
    rtol::Real = 1e-6,
    kwargs...,
)
    return jsr_bound(template, graph, problem; optimizer, rtol = rtol, kwargs...)
end

objective(certificate::StabilityCertificate) = certificate.rate

"""
    optimality_gap(certificate::StabilityCertificate; atol = 1e-4, max_length = nothing)

How far the rate is known to be from the joint spectral radius: `0` when
[`is_jsr_exact`](@ref) holds, and otherwise the rate minus
[`jsr_lower_bound`](@ref), the cycle bracket. `atol` reads tightness and
`max_length` bounds the cycle search, as in those two.

The bracket is sound whatever `atol` was; the structural test is not, and it is
skipped on a [`WordGraph`](@ref), where it is not yet proved.
"""
function optimality_gap(
    certificate::StabilityCertificate;
    atol::Real = 1e-4,
    max_length::Union{Nothing, Integer} = nothing,
)
    is_letter_graph(graph(certificate)) &&
        is_jsr_exact(certificate; atol = atol) &&
        return zero(certificate.rate)

    return certificate.rate -
           jsr_lower_bound(certificate; atol = atol, max_length = max_length)
end

# --- Reading a solved certificate: where it is tight --------------------------

function edge_slacks(certificate::StabilityCertificate)
    is_feasible(certificate) ||
        throw(ArgumentError("an infeasible certificate has no functions to measure"))

    graph_ = graph(certificate)
    template_ = template(certificate)
    V = functions(certificate)
    A = mode_matrices(problem(certificate).system)
    degree = homogeneity_degree(template_)

    # The certificate stores gamma; the edge inequality is imposed at
    # gamma^(d |w|), exactly as `optimization_model` builds it.
    return map(edges(graph_)) do edge
        word = letters(label(graph_, edge))

        return domination_slack(
            template_,
            V[source(edge)],
            V[dest(edge)],
            _product(A, word);
            scale = certificate.rate^(degree * length(word)),
        )
    end
end

"""
    is_jsr_exact(certificate; atol = 1e-6) -> Bool

Whether the certificate's rate is the **exact** joint spectral radius, by the
optimality certificate of Ninite & Jungers (Theorem 4): if every node has at
most one outgoing edge in the [`tight_subgraph`](@ref), then `γ*(G) = ρ(A)`.

The constrained precedent is Theorem 3.8 of Philippe, Essick, Dullerud &
Jungers, where the tight edges form a simple cycle. Letter graphs only: the
theorem is not proved with words on the edges, and [`jsr_lower_bound`](@ref)
needs no such proof.

!!! warning "Sufficient, not necessary — and `atol`-dependent"
    `false` means *unknown*, never "inexact". A graph can attain the exact rate
    with every edge tight, where the condition cannot hold: two opposite
    rotations scaled by `0.9` do exactly that.

    And the test is only as good as `atol`. Too small, and genuinely active
    edges are missed, the subgraph is too thin, and this returns `true` without
    grounds. [`jsr_lower_bound`](@ref) is the tolerance-free alternative: it
    brackets the answer instead of asserting it.
"""
function is_jsr_exact(certificate::StabilityCertificate; atol::Real = 1e-6)
    _require_letters(graph(certificate), "is_jsr_exact")

    subgraph = tight_subgraph(certificate; atol = atol)

    return all(node -> outdegree(subgraph, node) <= 1, nodes(subgraph))
end

"""
    jsr_lower_bound(certificate; atol = 1e-6, max_length = nothing)

A **lower** bound on the joint spectral radius, from the cycles of the
[`tight_subgraph`](@ref).

A cycle `(a₁,a₂,w₁) … (a_k,a₁,w_k)` of the graph forces
`γ ≥ ρ(A_{w_k} ⋯ A_{w_1})^{1/ℓ}` with `ℓ` the number of modes read along it,
and any product of modes bounds the joint spectral radius from below (Ninite &
Jungers, Lemma 1; Philippe, Essick, Dullerud & Jungers, Lemma 3.7). The largest
such value over the cycles found is returned; `0` when there are none.

Together with the certificate's own rate — an *upper* bound — this brackets the
answer, and **the bracket holds whatever `atol` was**: a cycle of the tight
subgraph is still a cycle of the graph, so its bound is valid even if the tight
set was identified badly. `atol` only decides where to look for good cycles, and
`max_length` how far; both affect how tight the bound is, neither whether it is
true. That is what makes this the honest companion to [`is_jsr_exact`](@ref).

`max_length` defaults to the number of nodes, which enumerates every simple
cycle. That is affordable at the sizes refinement reaches — measured against the
bisection it accompanies, on a graph whose edges are *all* tight, it costs 0.02%
at 4 nodes, 0.04% at 8 and 0.6% at 16 — but the cycle count over those sizes runs
6, 19, 179, so lower `max_length` before the graph is much larger. A truncated
search weakens the bound without making it wrong.
"""
function jsr_lower_bound(
    certificate::StabilityCertificate;
    atol::Real = 1e-6,
    max_length::Union{Nothing, Integer} = nothing,
)
    subgraph = tight_subgraph(certificate; atol = atol)
    A = mode_matrices(problem(certificate).system)

    length_bound = something(max_length, n_nodes(subgraph))
    best = zero(float(eltype(first(A))))

    for cycle in simple_cycles(subgraph; max_length = length_bound)
        # Composing the edge inequalities along the cycle puts the last mode
        # leftmost, which is also the order in which they act: the first read
        # is applied first. A word edge reads several.
        product = LinearAlgebra.I
        steps = 0

        for edge in cycle
            word = letters(label(subgraph, edge))
            product = _product(A, word) * product
            steps += length(word)
        end

        radius = maximum(abs, LinearAlgebra.eigvals(Matrix(product)))
        best = max(best, radius^(1 / steps))
    end

    return best
end
