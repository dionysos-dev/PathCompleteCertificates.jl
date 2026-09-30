
"""
    StabilityProblem(system)

Stability problem for an input-free switched linear system.

The problem stores the system only. The decay rate `gamma` is specified
when constructing the feasibility model.
"""
struct StabilityProblem{S} <: AbstractProblem
    system::S

    function StabilityProblem(system::S) where {S}
        # Without this, `mode_matrices` returns the (A, B) pair and the failure
        # surfaces much later as a MethodError inside the model builder.
        has_input(system) &&
            throw(ArgumentError("StabilityProblem requires an input-free system"))

        return new{typeof(system)}(system)
    end
end

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

# One method, generic over templates. `rate` is gamma^rate_exponent(template),
# and the whole edge condition of this problem is the template's domination
# primitive with that scale -- so a new template needs nothing here.
function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    template::AbstractTemplate,
    V_src,
    V_dst,
    A::AbstractMatrix;
    rate::Real = 1,
)
    add_domination!(model, template, V_src, V_dst, A; scale = rate)

    return nothing
end

"""
    optimization_model(template, graph, problem, gamma; optimizer)

Create the feasibility problem for the Lyapunov inequalities

    V_b(A_i x) <= gamma^2 * V_a(x)

for every edge `(a, b, i)` of `graph`.

The returned model has no objective. Use [`is_stable`](@ref) or
[`jsr_bound`](@ref) to solve it.

`LinearCopositiveTemplate` requires entrywise nonnegative matrices.
`optimizer` must be an LP solver for that template and an SDP-capable
solver for `QuadraticTemplate`.
"""
function optimization_model(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem,
    gamma::Real;
    optimizer,
    path_complete::Bool = true,
)
    gamma >= 0 || throw(ArgumentError("gamma must be nonnegative"))

    A = mode_matrices(problem.system)

    _check_stability_data(template, graph, A; path_complete = path_complete)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    dimension = size(first(A), 1)

    Vs = [add_function_variables!(model, template, dimension, a) for a in nodes(graph)]

    for V in Vs
        add_nonnegativity!(model, template, V)
        add_normalization!(model, template, V)
    end

    # The template's degree of homogeneity, not a hard-coded square: `gamma` is
    # the contraction rate for every template, so `jsr_bound` means the same
    # thing whichever one is in use.
    rate = gamma^rate_exponent(template)

    for edge in edges(graph)
        add_edge_constraint!(
            model,
            problem,
            template,
            Vs[source(edge)],
            Vs[dest(edge)],
            A[label(graph, edge)];
            rate = rate,
        )
    end

    model[:stability_V] = Vs

    return model
end

"""
    is_stable(template, graph, problem, gamma; optimizer) -> Bool

Return whether the fixed-`gamma` Lyapunov feasibility problem is solved
to a feasible termination status.
"""
function is_stable(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem,
    gamma::Real;
    optimizer,
    path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem,
        gamma;
        optimizer,
        path_complete = path_complete,
    )

    JuMP.optimize!(model)

    return JuMP.termination_status(model) in _FEASIBLE_TERMINATION_STATUSES
end

"""
    jsr_bound(template, graph, problem; optimizer, rtol = 1e-3,
              max_iterations = 100, initial_upper = 1.0)

Estimate an upper bound on the joint spectral radius by bisection.

At each candidate `gamma`, solve the fixed-`gamma` feasibility problem
over every edge `(a, b, i)`.

Returns a [`StabilityCertificate`](@ref). Its `rate` is the smallest feasible
bound found to relative tolerance `rtol`; `functions(certificate)` are the
node Lyapunov functions, and `certificate(x)` evaluates the common one.
"""
function jsr_bound(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
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

    A = mode_matrices(problem.system)

    # Once, here. The bisection below builds a model per step and each build
    # revalidates, so leaving this on would run a PSPACE-complete test a dozen
    # times over on a graph that cannot have changed.
    _check_stability_data(template, graph, A; path_complete = path_complete)

    lower = zero(initial_upper)
    upper = initial_upper

    while !is_stable(template, graph, problem, upper; optimizer, path_complete = false)
        upper *= 2

        isfinite(upper) ||
            throw(ArgumentError("could not find a finite feasible upper bound"))
    end

    for _ in 1:max_iterations
        upper - lower <= rtol * upper && break

        candidate = (lower + upper) / 2

        if is_stable(template, graph, problem, candidate; optimizer, path_complete = false)
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

Solve the fixed-`rate` Lyapunov feasibility problem once.

This is the single solve; [`jsr_bound`](@ref) bisects on `rate` on top of it,
and [`is_stable`](@ref) asks only whether a given rate is feasible.
"""
function certify(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    rate::Real = 1,
    path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem,
        rate;
        optimizer = optimizer,
        path_complete = path_complete,
    )

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
    jsr_bound(template, graph, system; kwargs...)

Estimate a joint-spectral-radius bound for an input-free switched system.
"""
function jsr_bound(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    system::_HS.HybridSystem;
    kwargs...,
)
    problem = StabilityProblem(system)

    return jsr_bound(template, graph, problem; kwargs...)
end

function _check_stability_data(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    A::AbstractVector{<:AbstractMatrix};
    path_complete::Bool = true,
)
    _check_modes(graph, A; path_complete = path_complete)
    check_dynamics(template, A)

    return nothing
end

"""
    edge_slacks(certificate)

The slack of every edge inequality, in `edges(graph(certificate))` order.

Zero means the edge is tight: the certificate is held at exactly that
inequality, and no smaller rate is available without changing the graph or the
template. A large value means the edge is not what limits the bound.

Throws on an infeasible certificate, which has no fitted functions to measure.
"""
function edge_slacks(certificate::StabilityCertificate)
    is_feasible(certificate) ||
        throw(ArgumentError("an infeasible certificate has no functions to measure"))

    graph_ = graph(certificate)
    template_ = template(certificate)
    V = functions(certificate)
    A = mode_matrices(problem(certificate).system)

    # The certificate stores gamma; the edge inequality is imposed at
    # gamma^d, exactly as `optimization_model` builds it.
    scale = certificate.rate^rate_exponent(template_)

    return [
        domination_slack(
            template_,
            V[source(edge)],
            V[dest(edge)],
            A[label(graph_, edge)];
            scale = scale,
        ) for edge in edges(graph_)
    ]
end

"""
    tight_edges(certificate; atol = 1e-6)

The edges whose inequality is active, as `(source, destination, mode)` tuples.

These are the edges that hold the bound up. A node with **two or more** tight
outgoing edges is the one a refinement step splits: it is being asked to serve
two futures with a single function, and giving it one copy per successor is
what buys a tighter rate.

`atol` is absolute, and a certificate is only determined up to scale — so read
it against [`edge_slacks`](@ref) rather than trusting a default on a template
whose normalisation you have not checked.
"""
function tight_edges(certificate::StabilityCertificate; atol::Real = 1e-6)
    graph_ = graph(certificate)
    slacks = edge_slacks(certificate)

    return [
        (source(edge), dest(edge), label(graph_, edge)) for
        (edge, slack) in zip(edges(graph_), slacks) if slack <= atol
    ]
end

"""
    tight_subgraph(certificate; atol = 1e-6)

The subgraph of the edges whose inequality is active — Definition 4 of Ninite &
Jungers, `Ē = {(a,b,i) ∈ E : λ_min(γ²P_a − Aᵢᵀ P_b A_i) = 0}`.

Same nodes as the certificate's graph, so node numbers carry over; only edges
are dropped. `atol` stands in for the exact zero, which a bisected solution
never reaches — see [`refine`](@ref) on choosing it.

This is the object the optimality theory is stated on: [`is_jsr_exact`](@ref)
reads its out-degrees and [`jsr_lower_bound`](@ref) its cycles.
"""
function tight_subgraph(certificate::StabilityCertificate; atol::Real = 1e-6)
    graph_ = graph(certificate)
    subgraph = _HS.GraphAutomaton(n_nodes(graph_))

    for (source_node, destination, mode) in tight_edges(certificate; atol = atol)
        _HS.add_transition!(subgraph, source_node, destination, mode)
    end

    return subgraph
end

"""
    is_jsr_exact(certificate; atol = 1e-6) -> Bool

Whether the certificate's rate is the **exact** joint spectral radius, by the
optimality certificate of Ninite & Jungers (Theorem 4): if every node has at
most one outgoing edge in the [`tight_subgraph`](@ref), then `γ*(G) = ρ(A)`.

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
    subgraph = tight_subgraph(certificate; atol = atol)

    return all(node -> outdegree(subgraph, node) <= 1, nodes(subgraph))
end

"""
    jsr_lower_bound(certificate; atol = 1e-6, max_length = nothing)

A **lower** bound on the joint spectral radius, from the cycles of the
[`tight_subgraph`](@ref).

A cycle `(a₁,a₂,i₁) … (a_k,a₁,i_k)` of the graph forces
`γ ≥ ρ(A_{i_k} ⋯ A_{i_1})^{1/k}`, and any product of modes bounds the joint
spectral radius from below (Ninite & Jungers, Lemma 1). The largest such value
over the cycles found is returned; `0` when there are none.

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
        # leftmost, which is also the order in which they act: A_{i_1} first.
        product = LinearAlgebra.I

        for edge in cycle
            product = A[label(subgraph, edge)] * product
        end

        radius = maximum(abs, LinearAlgebra.eigvals(Matrix(product)))
        best = max(best, radius^(1 / length(cycle)))
    end

    return best
end
