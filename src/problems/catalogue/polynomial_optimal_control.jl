const _FixedGainControlFamily =
    Union{SetProg.PolySet, SetProg.Polytope, AbstractVector{<:SetProg.Polytope}}
_fixed_gain_control_case(::SetProg.Polytope, problem) = Val(problem.p in (1, 2))
_fixed_gain_control_case(templates::AbstractVector{<:SetProg.Polytope}, problem) =
    Val(!isempty(templates) && problem.p in (1, 2))
_control_support(::SetProg.PolySet, n) = ones(n)
_control_support(::Union{SetProg.Polytope, AbstractVector{<:SetProg.Polytope}}, n) = nothing
_control_proof_scale(::SetProg.PolySet, problem, scale) = scale^(problem.p / 2)
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

"""
    optimization_model(template, graph, problem::OptimalControlProblem;
                       optimizer, gains, margin = 0)

Optimize value bounds for fixed node feedback gains. `Polytope` families
with fixed `piecewise` partitions support `p = 1` (LP) and `p = 2` (SOCP).
Their values are the p-th powers of their gauges. A vector of such families
can supply a different partition at each node. The objective minimizes
integrals of their linear gauges over bounded cone sections.

For polynomial bounds, the family must be symmetric and convex, with its
homogeneous degree equal to `problem.p`. For example, use
`PolySet(symmetric = true, convex = true, degree = 4)`
and `OptimalControlProblem(system, Q, R; p = 4)`.

Bellman inequalities are `PolarLpSum` inclusions with exponent `problem.p`.
The objective minimizes the sum of the value polynomials' integrals over
`[-1, 1]^n`, using SetProg's volume heuristic. `margin` adds a multiple of
`‖x‖^p` to each normalized stage cost. The gain matrices are fixed data.
For polyhedral values, ray certificates impose the same margin.
"""
function optimization_model(
    template::_FixedGainControlFamily,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    gains,
    margin::Real = 0,
)
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
            initialization_psd_margin = 1e-4)

Optimize polynomial or polyhedral value bounds for supplied node gains.
If `gains` is omitted, initialize them with the quadratic solver using the same `Q` and `R`
and exponent two. This initialization must succeed; gains can instead be
supplied explicitly. The value optimization then keeps these matrices fixed.
For fixed polyhedral costs, initialization uses identity quadratic costs.
`initialization_optimizer` defaults to `optimizer`; set it to an SDP solver
when using an LP solver for the polyhedral problem.

The returned certificate uses the node with smallest powered-gauge value to
select its gain. Polynomial `edge_slacks` are the minimum eigenvalues of the
fitted SOS Gram certificates in physical cost units. Polyhedral edge proofs
are LP slacks or SOC arrow matrices in gauge units.
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
)
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

node_value(
    ::OptimalControlProblem,
    V::SetProg.Sets.AbstractSet,
    x::AbstractVector{<:Real},
) = SetProg.sublevel_eval(V, x)

# A linear-piece set represents its gauge, whereas the control value is its
# p-th power (piecewise quadratic when p=2).
node_value(problem::OptimalControlProblem, V::_LinearPolytope, x::AbstractVector{<:Real}) =
    max(0, SetProg.sublevel_eval(V, x))^problem.p
