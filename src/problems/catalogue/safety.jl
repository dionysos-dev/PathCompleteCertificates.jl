"""
    SafetyProblem(system, S0, Su)

Safety problem for an input-free switched linear system [anand2024barrier](@cite),
with initial and unsafe sets `{x : [x; 1]' S [x; 1] ≥ 0}` for `S = S0, Su`.
For a quadratic family, the barrier at node `a` is `[x; 1]' P_a [x; 1]`
with `P_a` symmetric, not necessarily positive semidefinite. Polynomial
families construct affine polynomial barriers of the requested degree.
"""
struct SafetyProblem{S, M0 <: AbstractMatrix, Mu <: AbstractMatrix} <: AbstractProblem
    system::S
    S0::M0
    Su::Mu

    function SafetyProblem(
        system::S,
        S0::M0,
        Su::Mu,
    ) where {S, M0 <: AbstractMatrix, Mu <: AbstractMatrix}
        has_input(system) &&
            throw(ArgumentError("SafetyProblem requires an input-free system"))

        n = _check_state_matrices(state_matrices(system))
        d = n + 1

        size(S0) == (d, d) ||
            throw(ArgumentError("S0 has size $(size(S0)); expected ($d, $d)"))

        size(Su) == (d, d) ||
            throw(ArgumentError("Su has size $(size(Su)); expected ($d, $d)"))

        isapprox(S0, transpose(S0)) || throw(ArgumentError("S0 must be symmetric"))

        isapprox(Su, transpose(Su)) || throw(ArgumentError("Su must be symmetric"))

        return new{S, M0, Mu}(system, S0, Su)
    end
end

"""
    SafetyCertificate

A path-complete barrier function, its `margin` of separation between the
initial and unsafe sets (positive when safety is certified), and the S-procedure
multipliers `initial_multipliers` and `unsafe_multipliers`, one per node.
"""
struct SafetyCertificate{D <: CertificateData, T, M} <: AbstractCertificate
    data::D
    margin::T
    initial_multipliers::M
    unsafe_multipliers::M
end

# Barriers are evaluated in physical state coordinates.
_edge_decrease(::SafetyProblem, graph::CertificateGraph, edge, A) =
    (A[only(letters(label(graph, edge)))], 1)

function _safety_family(f::SetProg.Ellipsoid, n, variables)
    f.dimension === nothing || f.dimension == n || throw(DimensionMismatch())
    f.point === nothing && f.piecewise === nothing && f.superset === nothing ||
        throw(ArgumentError("safety does not support point, piecewise, or superset hints"))
    return SetProg.Ellipsoid(; symmetric = false, psd = false, dimension = n)
end
function _safety_family(f::SetProg.PolySet, n, variables)
    f.dimension === nothing || f.dimension == n || throw(DimensionMismatch())
    f.point === nothing || throw(ArgumentError("safety does not support a point hint"))
    length(variables) == n || throw(DimensionMismatch())
    return SetProg.PolySet(;
        symmetric = false,
        psd = false,
        dimension = n,
        degree = f.degree,
        variables,
        basis = f.basis,
    )
end
_safety_degree(::SetProg.Ellipsoid) = 2
_safety_degree(f::SetProg.PolySet) = f.degree

function _safety_families(template, n, count)
    families = template isa AbstractVector ? template : fill(template, count)
    length(families) == count || throw(ArgumentError("one set family is required per node"))
    polys = filter(f -> f isa SetProg.PolySet, families)
    x = nothing
    if !isempty(polys)
        explicit = [f.variables for f in polys if f.variables !== nothing]
        x = isempty(explicit) ? SetProg.new_polyvars(n) : first(explicit)
        all(==(x), explicit) ||
            throw(ArgumentError("polynomial sets must share their variables"))
    end
    return [_safety_family(f, n, x) for f in families]
end

# Input matrices have the constant coordinate last, unlike ShiftedEllipsoid.
_safety_region(M) = SetProg.Sets.ShiftedEllipsoid(
    LinearAlgebra.Symmetric(M[1:(end - 1), 1:(end - 1)]),
    M[1:(end - 1), end],
    M[end, end],
)
_safety_reference(f::SetProg.Ellipsoid, sign) = _safety_region(
    sign * Matrix{Float64}(LinearAlgebra.I, f.dimension + 1, f.dimension + 1),
)

"""
    optimization_model(template, graph, problem; optimizer, check_path_complete = true)

Build the barrier program with quadratic or polynomial SetProg families.
Safety uses affine barriers without a positivity constraint. Two fixed-scale
inclusions bound their coefficients; separation from the initial and unsafe
sets uses nonnegative S-procedure multipliers.
"""
function optimization_model(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::SafetyProblem;
    optimizer,
    check_path_complete::Bool = true,
)
    _check_safety_data(graph, problem; check_path_complete)
    families = _safety_families(template, _state_dimension(problem.system), n_nodes(graph))
    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)
    sets = [JuMP.@variable(model, variable_type = f) for f in families]
    gamma0 = [
        SetProg.SProcedureMultiplier(;
            degree = _safety_degree(f) - 2,
            base_name = "gamma0_$i",
        ) for (i, f) in enumerate(families)
    ]
    gammau = [
        SetProg.SProcedureMultiplier(;
            degree = _safety_degree(f) - 2,
            base_name = "gammau_$i",
        ) for (i, f) in enumerate(families)
    ]
    eps = JuMP.@variable(model, lower_bound = 0, base_name = "eps")
    initial = _safety_region(-problem.S0)
    unsafe = _safety_region(-problem.Su)
    separation = []
    for i in nodes(graph)
        push!(
            separation,
            JuMP.@constraint(
                model,
                initial ⊆ sets[i],
                S_procedure_scaling = gamma0[i],
                margin = eps
            )
        )
        push!(
            separation,
            JuMP.@constraint(
                model,
                [sets[i], unsafe] in SetProg.Disjoint(),
                S_procedure_scaling = gammau[i],
                margin = eps
            )
        )
        # Fixed multipliers bound B between ±(1 + ‖x‖²)^d. For quadratics,
        # these are exactly I - P ⪰ 0 and P + I ⪰ 0.
        upper = _safety_reference(families[i], 1)
        lower = _safety_reference(families[i], -1)
        JuMP.@constraint(model, upper ⊆ sets[i], S_procedure_scaling = 1)
        JuMP.@constraint(model, sets[i] ⊆ lower, S_procedure_scaling = 1)
    end
    A = state_matrices(problem.system)
    for edge in edges(graph)
        dynamics, _ = _edge_decrease(problem, graph, edge, A)
        JuMP.@constraint(model, dynamics * sets[source(edge)] ⊆ sets[dest(edge)])
    end
    JuMP.@objective(model, Max, eps)
    model[:safety_sets] = sets
    model[:safety_gamma0] = gamma0
    model[:safety_gammau] = gammau
    model[:safety_eps] = eps
    model[:safety_separation] = separation
    return model
end

"""
    certify(template, graph, problem; optimizer, check_path_complete = true)

Solve the barrier program and return a [`SafetyCertificate`](@ref).
"""
function certify(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::SafetyProblem;
    optimizer,
    check_path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem;
        optimizer = optimizer,
        check_path_complete = check_path_complete,
    )

    JuMP.optimize!(model)
    termination = JuMP.termination_status(model)

    JuMP.is_solved_and_feasible(model; allow_almost = true) || return SafetyCertificate(
        _failed(problem, template, graph, termination),
        nothing,
        nothing,
        nothing,
    )

    Pval = JuMP.value.(model[:safety_sets])
    gamma0_val = JuMP.value.(model[:safety_gamma0])
    gammau_val = JuMP.value.(model[:safety_gammau])
    eps_val = JuMP.value(model[:safety_eps])

    # Re-check the returned PSD/SOS certificates, including their margin.
    feasible =
        eps_val > _SAFETY_MARGIN_TOLERANCE && all(model[:safety_separation]) do constraint
            matrix = SetProg.certificate_matrix(constraint)
            return minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(matrix))) >=
                   -_SAFETY_CHECK_TOLERANCE
        end

    return SafetyCertificate(
        CertificateData(problem, template, graph, Pval, termination, feasible),
        eps_val,
        gamma0_val,
        gammau_val,
    )
end

# Smallest margin counted as a separation; below it is solver noise.
const _SAFETY_MARGIN_TOLERANCE = 1e-8

# How far below the margin a separation of the solution may fall, as solver
# error.
const _SAFETY_CHECK_TOLERANCE = 1e-7

# The map x⁺ = A x in homogeneous coordinates.
function _homogeneous_dynamics(A::AbstractMatrix)
    n = size(A, 1)

    return [
        A zeros(n, 1)
        zeros(1, n) 1.0
    ]
end

# Validate the data.
function _check_safety_data(
    graph::CertificateGraph,
    problem::SafetyProblem;
    check_path_complete::Bool = true,
)
    _require_one_mode_per_edge(graph, "SafetyProblem")
    _check_graph_suitability(
        graph,
        problem.system;
        check_path_complete = check_path_complete,
    )
    return nothing
end

# Evaluate the barrier in physical state coordinates.
node_value(::SafetyProblem, V, x::AbstractVector{<:Real}) = SetProg.sublevel_eval(V, x) - 1

# Where the barrier is held; `refine` does not run on safety.
edge_slacks(certificate::SafetyCertificate) = _edge_slacks(certificate)

function decrease_slack(
    ::SetProg.Ellipsoid,
    source::SetProg.Sets.ShiftedEllipsoid,
    destination::SetProg.Sets.ShiftedEllipsoid,
    A;
    scale = 1,
)
    H(V) = [V.β V.b'; V.b V.Q]
    dynamics = [1.0 zeros(1, size(A, 2)); zeros(size(A, 1)) A]
    residual = scale * H(source) - dynamics' * H(destination) * dynamics
    return minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(residual)))
end
