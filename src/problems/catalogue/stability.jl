"""
    StabilityProblem(system)

Stability problem for an input-free switched linear system, certified at a
given rate by [`certify`](@ref) or at the smallest rate by [`jsr_bound`](@ref).
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

A path-complete Lyapunov function and its `rate`, an upper bound on the joint
spectral radius.
"""
struct StabilityCertificate{D <: CertificateData, T <: Real} <: AbstractCertificate
    data::D
    rate::T
end

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

The feasibility problem `V_b(A_w x) <= rate^(p |w|) * V_a(x)` for every edge
`(a, b, w)`, with `p` the template's degree and `|w|` the length of the word.
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

The [`StabilityCertificate`](@ref) of the smallest feasible rate, to relative
tolerance `rtol`. `initial_upper` is a first guess of a feasible rate.
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

    # Check path-completeness once; the models built below skip it.
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

Solve the stability problem at the fixed `rate`.
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

The certificate on the dual graph made of the dual norms of the node functions,
at the same rate. Requires a template that [`has_dual`](@ref).
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
[`is_jsr_exact`](@ref) holds, otherwise the rate minus [`jsr_lower_bound`](@ref).
"""
function optimality_gap(
    certificate::StabilityCertificate;
    atol::Real = 1e-4,
    max_length::Union{Nothing, Integer} = nothing,
)
    !has_words(graph(certificate)) &&
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

Whether every node has at most one outgoing edge in the
[`tight_subgraph`](@ref), which proves the rate is the joint spectral radius
[ninite2026lifting; Thm. 4](@cite). `false` means unknown; too small an `atol`
can give a wrong `true`. Throws on a graph with words; use `expanded_form`.
"""
function is_jsr_exact(certificate::StabilityCertificate; atol::Real = 1e-6)
    _require_one_mode_per_edge(graph(certificate), "is_jsr_exact")

    subgraph = tight_subgraph(certificate; atol = atol)

    return all(node -> outdegree(subgraph, node) <= 1, nodes(subgraph))
end

"""
    jsr_lower_bound(certificate; atol = 1e-6, max_length = nothing)

A lower bound on the joint spectral radius, valid for any `atol`: the largest
`ρ(A_w)^{1/|w|}` over the words `w` read along the simple cycles of at most
`max_length` edges of the [`tight_subgraph`](@ref); `0` if there are none.
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
        # The first mode read acts first, so later modes multiply on the left.
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
