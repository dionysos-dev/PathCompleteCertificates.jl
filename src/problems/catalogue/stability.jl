"""
    StabilityProblem(system)

Stability problem for an input-free switched linear system, certified by
[`certify`](@ref) at the smallest rate, or at a given one.
"""
struct StabilityProblem{S} <: AbstractProblem
    system::S

    function StabilityProblem(system::S) where {S}
        has_input(system) &&
            throw(ArgumentError("StabilityProblem requires an input-free system"))
        _check_state_matrices(state_matrices(system))

        return new{S}(system)
    end
end

dual(problem::StabilityProblem) = StabilityProblem(dual(problem.system))

node_value(::StabilityProblem, V::SetProg.Sets.AbstractSet, x::AbstractVector{<:Real}) =
    _gauge(V, x)

"""
    StabilityCertificate

A path-complete Lyapunov function and its `rate`, an upper bound on the joint
spectral radius.
"""
struct StabilityCertificate{D <: CertificateData, T <: Real} <: AbstractCertificate
    data::D
    rate::T
end

# The decrease condition of `edge`: the product of the matrices it reads, and the
# scale of its source side. Written once, for the model and for the slacks.
function _edge_decrease(
    ::StabilityProblem,
    graph::CertificateGraph,
    edge,
    A;
    rate::Real,
    degree::Integer,
)
    word = letters(label(graph, edge))
    return _product(A, word), rate^(degree * length(word))
end

"""
    optimization_model(family, graph, problem; optimizer, rate = 1,
                       conditioning_bound = Inf)

A SetProg model, whose set variables are expanded when optimized, for
the feasibility problem `V_b(A_w x) <= rate^(p |w|) * V_a(x)` for every edge
`(a, b, w)`, with `p` the template's degree and `|w|` the length of the word.
"""
function optimization_model(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::StabilityProblem;
    optimizer,
    rate::Real = 1,
    check_path_complete::Bool = true,
    conditioning_bound::Real = Inf,
)
    rate >= 0 || throw(ArgumentError("the rate must be nonnegative"))

    _check_stability_data(
        template,
        graph,
        problem;
        check_path_complete = check_path_complete,
    )
    dimension = _state_dimension(problem.system)
    A = state_matrices(problem.system)
    degree = homogeneity_degree(template)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    families = _prepared_families(template, dimension, n_nodes(graph))
    Vs = [add_function_variables!(model, families[a], dimension, a) for a in nodes(graph)]

    for V in Vs
        add_normalization!(model, V.set, V; conditioning_bound)
    end

    for edge in edges(graph)
        dynamics, scale = _edge_decrease(problem, graph, edge, A; rate, degree)
        add_decrease!(
            model,
            Vs[source(edge)].set,
            Vs[source(edge)],
            Vs[dest(edge)],
            dynamics;
            scale,
        )
    end

    model[:stability_V] = Vs

    return model
end

"""
    certify(template, graph, problem::StabilityProblem; optimizer, rate = nothing,
            rtol = 1e-6, max_iterations = 100, initial_upper = 1.0,
            check_path_complete = true, conditioning_bound = Inf)

The [`StabilityCertificate`](@ref) of the smallest feasible rate, an upper bound
on the joint spectral radius, found by bisection to relative tolerance `rtol`,
using a SetProg family or a vector of families, one per node. `initial_upper`
is a first guess of a feasible rate. Given a `rate`, solve at that rate only. A
finite `conditioning_bound` bounds ellipsoid gauge matrices between `I` and
`conditioning_bound * I`.

`rtol` is that of [`refine`](@ref), so that the default `atol` of
[`tight_edges`](@ref) is at least ten times it: a certificate read at a coarser
`rtol` needs a larger `atol`.
"""
function certify(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::StabilityProblem;
    optimizer,
    rate::Union{Real, Nothing} = nothing,
    rtol::Real = 1e-6,
    max_iterations::Integer = 100,
    initial_upper::Real = 1.0,
    check_path_complete::Bool = true,
    conditioning_bound::Real = Inf,
)
    rate === nothing || return _certify_at(
        template,
        graph,
        problem,
        rate;
        optimizer,
        check_path_complete,
        conditioning_bound,
    )

    rtol > 0 || throw(ArgumentError("rtol must be positive"))

    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive"))

    initial_upper > 0 || throw(ArgumentError("initial_upper must be positive"))

    # Check path-completeness once; the models built below skip it.
    _check_stability_data(
        template,
        graph,
        problem;
        check_path_complete = check_path_complete,
    )

    function feasible(rate)
        model = optimization_model(
            template,
            graph,
            problem;
            optimizer,
            rate,
            check_path_complete = false,
            conditioning_bound = conditioning_bound,
        )
        JuMP.optimize!(model)
        return JuMP.is_solved_and_feasible(model; allow_almost = true)
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

    certificate = _certify_at(
        template,
        graph,
        problem,
        upper;
        optimizer,
        check_path_complete = false,
        conditioning_bound,
    )

    is_feasible(certificate) ||
        throw(ArgumentError("the final stability problem is not feasible"))

    return certificate
end

# Solve the stability problem at the fixed `rate`.
function _certify_at(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::StabilityProblem,
    rate::Real;
    optimizer,
    check_path_complete::Bool,
    conditioning_bound::Real,
)
    model = optimization_model(
        template,
        graph,
        problem;
        optimizer,
        rate,
        check_path_complete,
        conditioning_bound,
    )

    JuMP.optimize!(model)
    termination = JuMP.termination_status(model)

    JuMP.is_solved_and_feasible(model; allow_almost = true) ||
        return StabilityCertificate(_failed(problem, template, graph, termination), rate)

    V = [solution_value(v.set, v) for v in model[:stability_V]]

    return StabilityCertificate(
        CertificateData(problem, template, graph, V, termination, true),
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
    template::_SetFamily,
    graph::CertificateGraph,
    problem::StabilityProblem;
    check_path_complete::Bool = true,
)
    _check_graph_suitability(
        graph,
        problem.system;
        check_path_complete = check_path_complete,
    )

    is_applicable(template, problem.system) || throw(
        ArgumentError(
            "$(nameof(typeof(template))) does not apply to this system's dynamics; " *
            "see its docstring",
        ),
    )

    return nothing
end

objective(certificate::StabilityCertificate) = certificate.rate

_refinable(::StabilityProblem) = true

"""
    optimality_gap(certificate::StabilityCertificate; atol = 1e-4, max_length = nothing)

How far the rate is known to be from the joint spectral radius: `0` when
[`is_jsr_exact`](@ref) holds, otherwise the rate minus [`jsr_lower_bound`](@ref).
"""
function optimality_gap(
    certificate::StabilityCertificate;
    atol::Real = _TIGHT_ATOL,
    max_length::Union{Nothing, Integer} = nothing,
)
    !has_words(graph(certificate)) &&
        is_jsr_exact(certificate; atol = atol) &&
        return zero(certificate.rate)

    return certificate.rate -
           jsr_lower_bound(certificate; atol = atol, max_length = max_length)
end

# --- Reading a solved certificate: where it is tight --------------------------

edge_slacks(certificate::StabilityCertificate) = _edge_slacks(
    certificate;
    rate = certificate.rate,
    degree = homogeneity_degree(template(certificate)),
)

"""
    is_jsr_exact(certificate; atol = 1e-4) -> Bool

Whether every node has at most one outgoing edge in the
[`tight_subgraph`](@ref), which proves the rate is the joint spectral radius
[ninite2026lifting; Thm. 4](@cite). `false` means unknown. At the optimal rate
the tight subgraph keeps the rate [ninite2026lifting; Prop. 1](@cite), so it
contains a cycle; without one, `atol` was too small to see the active edges and
the answer is `false`. Throws on a graph with words; use `expanded_form`.
"""
function is_jsr_exact(certificate::StabilityCertificate; atol::Real = _TIGHT_ATOL)
    _require_one_mode_per_edge(graph(certificate), "is_jsr_exact")

    subgraph = tight_subgraph(certificate; atol = atol)

    all(node -> outdegree(subgraph, node) <= 1, nodes(subgraph)) || return false

    return !isempty(simple_cycles(subgraph))
end

"""
    jsr_lower_bound(certificate; atol = 1e-4, max_length = nothing)

A lower bound on the joint spectral radius, valid for any `atol`: the largest
`ρ(A_w)^{1/|w|}` over the words `w` read along the simple cycles of at most
`max_length` edges of the [`tight_subgraph`](@ref); `0` if there are none.
"""
function jsr_lower_bound(
    certificate::StabilityCertificate;
    atol::Real = _TIGHT_ATOL,
    max_length::Union{Nothing, Integer} = nothing,
)
    subgraph = tight_subgraph(certificate; atol = atol)
    A = state_matrices(problem(certificate).system)

    length_bound = something(max_length, n_nodes(subgraph))
    best = zero(float(eltype(first(A))))

    for cycle in simple_cycles(subgraph; max_length = length_bound)
        # The word read around the cycle, the first mode first.
        word = [mode for edge in cycle for mode in letters(label(subgraph, edge))]
        radius = maximum(abs, LinearAlgebra.eigvals(Matrix(_product(A, word))))
        best = max(best, radius^(1 / length(word)))
    end

    return best
end
