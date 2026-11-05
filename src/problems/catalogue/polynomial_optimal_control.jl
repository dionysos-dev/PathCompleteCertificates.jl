const _FixedGainControlFamily = Union{
    SetProg.PolySet,
    SetProg.Polytope,
    SetProg.Ellipsoid,
    AbstractVector{<:SetProg.Polytope},
    AbstractVector{<:SetProg.Ellipsoid},
}
_fixed_gain_control_case(::SetProg.Polytope, problem) = Val(problem.p in (1, 2))
_fixed_gain_control_case(templates::AbstractVector{<:SetProg.Polytope}, problem) =
    Val(!isempty(templates) && problem.p in (1, 2))
_fixed_gain_control_case(template::SetProg.Ellipsoid, problem) = Val(
    template.symmetric && template.psd && template.piecewise !== nothing && problem.p == 2,
)
_fixed_gain_control_case(templates::AbstractVector{<:SetProg.Ellipsoid}, problem) = Val(
    !isempty(templates) &&
        all(t -> _fixed_gain_control_case(t, problem) == Val(true), templates),
)
_control_support(::SetProg.PolySet, n) = ones(n)
_control_support(::Union{SetProg.Ellipsoid, AbstractVector{<:SetProg.Ellipsoid}}, n) =
    nothing
_control_support(::Union{SetProg.Polytope, AbstractVector{<:SetProg.Polytope}}, n) = nothing
_control_proof_scale(
    ::Union{SetProg.PolySet, SetProg.Ellipsoid, AbstractVector{<:SetProg.Ellipsoid}},
    problem,
    scale,
) = scale^(problem.p / 2)
_control_proof_scale(
    ::Union{SetProg.Polytope, AbstractVector{<:SetProg.Polytope}},
    problem,
    scale,
) = sqrt(scale)

_fixed_gain_control_case(template, problem) = Val(
    template.convex &&
        template.symmetric &&
        template.degree isa Int &&
        template.degree == problem.p,
)
function _check_fixed_gain_control_case(::Val{true})
    return nothing
end
function _check_fixed_gain_control_case(::Val{false})
    return throw(
        ArgumentError(
            "fixed-gain optimal control needs symmetric, convex node functions whose " *
            "degree is the exponent p of the cost: " *
            "SumOfSquaresTemplate(r; convex = true) with p = 2r, " *
            "PiecewiseQuadraticTemplate with p = 2, or PiecewiseLinearTemplate " *
            "with p = 1 or p = 2",
        ),
    )
end

"""
    optimization_model(template, graph, problem::OptimalControlProblem;
                       optimizer, gains, margin = 0, psd_margin = 1e-4)

Build, without solving, the program of the node functions for fixed `gains`,
one matrix ``K_s`` per node. The degree ``\\delta`` of the node functions must
be the exponent `p` of the cost:

- `SumOfSquaresTemplate(r; convex = true)` with `p = 2r`, a semidefinite
  program.
- [`PiecewiseQuadraticTemplate`](@ref) with `p = 2`, a semidefinite program.
- [`PiecewiseLinearTemplate`](@ref) with `p = 1`, a linear program, or
  `p = 2`, a second-order cone program. The node functions are then
  ``g_{\\Omega_s}^p``.

A vector of templates gives a different partition at each node. The edge
inequality is imposed as a SetProg inclusion through the polar ``L_p`` sum.
The objective minimizes the integrals of the node functions, or of their
gauges for the piecewise linear template, over a bounded region. `margin` adds
a multiple of ``\\|x\\|^p`` to the stage cost.
"""
function optimization_model(
    template::_FixedGainControlFamily,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    gains = nothing,
    margin::Real = 0,
    psd_margin::Real = 1e-4,
)
    if template isa SetProg.Ellipsoid && template.piecewise === nothing
        _check_joint_control_inputs(gains, margin)
        return invoke(
            optimization_model,
            Tuple{_SetFamily, CertificateGraph, OptimalControlProblem},
            template,
            graph,
            problem;
            optimizer,
            psd_margin,
        )
    end
    _check_control_cost(template, problem)
    return _fixed_gain_control_model(
        _fixed_gain_control_case(template, problem),
        template,
        graph,
        problem;
        optimizer,
        gains,
        margin,
    )
end

function _fixed_gain_control_model(::Val{false}, ::Any, ::Any, ::Any; kwargs...)
    return _check_fixed_gain_control_case(Val(false))
end
function _fixed_gain_control_model(
    ::Val{true},
    template,
    graph,
    problem;
    optimizer,
    gains,
    margin,
)
    margin >= 0 || throw(ArgumentError("margin must be nonnegative"))
    _check_optimal_control_data(graph, problem)
    n = _state_dimension(problem.system)
    A, B = state_matrices(problem.system), input_matrices(problem.system)
    m = size(first(B), 2)
    gains === nothing && throw(ArgumentError("supply fixed gains to optimization_model"))
    length(gains) == n_nodes(graph) || throw(ArgumentError("one gain is required per node"))
    for K in gains
        size(K) == (m, n) || throw(DimensionMismatch("a gain must have size ($m, $n)"))
        all(isfinite, K) || throw(ArgumentError("gains must be finite"))
    end
    fixed_gains = [Matrix(K) for K in gains]
    families = _prepared_families(template, n, n_nodes(graph))
    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)
    sets = [JuMP.@variable(model, variable_type = f) for f in families]
    scale = _cost_scale(problem)
    state_cost = _control_cost_set(problem.Q, scale)
    input_cost = _control_cost_set(problem.R, scale)
    constraints = []
    for edge in edges(graph)
        a, b = source(edge), dest(edge)
        mode = only(letters(label(graph, edge)))
        stage = SetProg.PolarLpSum(
            state_cost,
            SetProg.Sets.LinearPreImage(input_cost, fixed_gains[a]),
            problem.p,
        )
        next = SetProg.Sets.LinearPreImage(sets[b], A[mode] + B[mode] * fixed_gains[a])
        push!(
            constraints,
            JuMP.@constraint(
                model,
                sets[a] ⊆ SetProg.PolarLpSum(next, stage, problem.p),
                margin = margin
            )
        )
    end
    objective = reduce(
        +,
        [
            SetProg.L1_heuristic(SetProg.volume(S), _control_support(template, n)) for
            S in sets
        ],
    )
    JuMP.@objective(model, Max, objective)
    model[:optimal_control_sets] = sets
    model[:optimal_control_gains] = fixed_gains
    model[:optimal_control_edges] = constraints
    return model
end

"""
    certify(template, graph, problem::OptimalControlProblem;
            optimizer, gains = nothing, margin = 0,
            initialization_optimizer = optimizer,
            initialization_psd_margin = 1e-4, psd_margin = 1e-4)

The best node functions for fixed `gains`, with the templates of the
fixed-gain [`optimization_model`](@ref), as an
[`OptimalControlCertificate`](@ref). Without `gains`, they are the gains of
the quadratic certificate for the same `Q` and `R` and `p = 2`, or for
identity costs when `Q` and `R` are polytopes. `initialization_optimizer`
computes them, so it must solve semidefinite programs, and `certify` throws if
that certificate is infeasible.

[`edge_slacks`](@ref) reads the smallest eigenvalue of the certificate of each
edge, or its linear or second-order cone slack for the piecewise linear
template.
"""
function certify(
    template::_FixedGainControlFamily,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    gains = nothing,
    margin::Real = 0,
    initialization_psd_margin::Real = 1e-4,
    initialization_optimizer = optimizer,
    psd_margin::Real = 1e-4,
)
    if template isa SetProg.Ellipsoid && template.piecewise === nothing
        _check_joint_control_inputs(gains, margin)
        return invoke(
            certify,
            Tuple{_SetFamily, CertificateGraph, OptimalControlProblem},
            template,
            graph,
            problem;
            optimizer,
            psd_margin,
        )
    end
    _check_control_cost(template, problem)
    _check_fixed_gain_control_case(_fixed_gain_control_case(template, problem))
    if gains === nothing
        seed = certify(
            QuadraticTemplate(),
            graph,
            OptimalControlProblem(
                problem.system,
                _initialization_cost(problem.Q),
                _initialization_cost(problem.R),
            );
            optimizer = initialization_optimizer,
            psd_margin = initialization_psd_margin,
        )
        is_feasible(seed) ||
            throw(ArgumentError("quadratic initialization failed; supply gains explicitly"))
        gains = seed.gains
    end
    model = optimization_model(template, graph, problem; optimizer, gains, margin)
    JuMP.optimize!(model)
    termination = JuMP.termination_status(model)
    JuMP.is_solved_and_feasible(model; allow_almost = true) ||
        return OptimalControlCertificate(
            _failed(problem, template, graph, termination),
            nothing,
        )
    scale = _cost_scale(problem)
    sets = JuMP.value.(model[:optimal_control_sets])
    # Scaling the gauge by sqrt(scale) restores the physical powered cost.
    # This works for both homogeneous polynomials and linear pieces.
    map =
        sqrt(scale) * Matrix{Float64}(
            LinearAlgebra.I,
            _state_dimension(problem.system),
            _state_dimension(problem.system),
        )
    functions = [
        SetProg.apply_map(
            SetProg.Sets.LinearPreImage(S, map),
            SetProg.Sets.space_variables(S),
        ) for S in sets
    ]
    normalized_proofs = SetProg.certificate_matrix.(model[:optimal_control_edges])
    feasible = all(
        M -> minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(M))) >= -1e-7,
        normalized_proofs,
    )
    proofs = [_control_proof_scale(template, problem, scale) * M for M in normalized_proofs]
    return OptimalControlCertificate(
        CertificateData(problem, template, graph, functions, termination, feasible),
        model[:optimal_control_gains],
        proofs,
    )
end

# SumOfSquaresTemplate is a normalized PolySet. The stage cost bounds every value
# function from below, so optimal control uses the PolySet alone, and the
# certificate keeps the template it was given.
function optimization_model(
    template::_NormalizedFamily{<:SetProg.PolySet},
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    kwargs...,
)
    return optimization_model(template.set, graph, problem; kwargs...)
end
function certify(
    template::_NormalizedFamily{<:SetProg.PolySet},
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    kwargs...,
)
    certificate = certify(template.set, graph, problem; kwargs...)
    data = _data(certificate)
    return OptimalControlCertificate(
        CertificateData(
            problem,
            template,
            graph,
            data.functions,
            data.status,
            data.feasible,
        ),
        certificate.gains,
        certificate.edge_certificates,
    )
end

node_value(
    ::OptimalControlProblem,
    V::SetProg.Sets.AbstractSet,
    x::AbstractVector{<:Real},
) = SetProg.sublevel_eval(V, x)

# A linear-piece set represents its gauge, whereas the control value is its
# p-th power (piecewise quadratic when p=2).
node_value(problem::OptimalControlProblem, V::_LinearPolytope, x::AbstractVector{<:Real}) =
    max(0, SetProg.sublevel_eval(V, x))^problem.p
