# Reference for path-complete barrier functions for safety of switched linear systems:
# M. Anand, R. Jungers, M. Zamani, and F. Allgöwer,
# "Path-Complete Barrier Functions for Safety of Switched Linear Systems", CDC 2024

import JuMP
import LinearAlgebra

"""
    SafetyProblem(system, S0, Su)

Path-complete safety problem for an input-free switched linear system.

S0 and Su describe the initial and unsafe sets in homogeneous
coordinates.

The candidate barrier functions are

    B_v(x) = [x; 1]' * P_v * [x; 1]

where P_v is symmetric but not necessarily positive semidefinite.
"""
struct SafetyProblem{S, M0 <: AbstractMatrix, Mu <: AbstractMatrix} <: AbstractProblem
    system::S
    S0::M0
    Su::Mu

    function SafetyProblem(system, S0::AbstractMatrix, Su::AbstractMatrix)
        has_input(system) &&
            throw(ArgumentError("SafetyProblem requires an input-free system"))

        A = mode_matrices(system)

        isempty(A) && throw(ArgumentError("at least one mode is required"))

        n = size(first(A), 1)
        d = n + 1

        size(S0) == (d, d) ||
            throw(ArgumentError("S0 has size $(size(S0)); expected ($d, $d)"))

        size(Su) == (d, d) ||
            throw(ArgumentError("Su has size $(size(Su)); expected ($d, $d)"))

        isapprox(S0, transpose(S0)) || throw(ArgumentError("S0 must be symmetric"))

        isapprox(Su, transpose(Su)) || throw(ArgumentError("Su must be symmetric"))

        return new{typeof(system), typeof(S0), typeof(Su)}(system, S0, Su)
    end
end

"""
    add_edge_constraint!(model, problem, template, P_src, P_dst, A, eps)

Add the barrier decrease inequality for one labelled graph edge.
"""
function add_edge_constraint! end

function add_edge_constraint!(
    model::JuMP.Model,
    problem::SafetyProblem,
    ::Type{QuadraticTemplate},
    P_src::LinearAlgebra.Symmetric,
    P_dst::LinearAlgebra.Symmetric,
    A::AbstractMatrix,
    eps::JuMP.VariableRef,
)
    T_A = _homogeneous_dynamics(A)
    d = size(A, 1) + 1

    JuMP.@constraint(
        model,
        P_src - transpose(T_A) * P_dst * T_A - eps * LinearAlgebra.I(d) in JuMP.PSDCone()
    )

    return nothing
end

"""
    safety_problem(template, graph, problem; optimizer)

Construct the path-complete barrier optimization model.
"""
function safety_problem(
    template::Type{<:AbstractTemplate},
    graph::Graph,
    problem::SafetyProblem;
    optimizer,
)
    template === QuadraticTemplate ||
        throw(ArgumentError("SafetyProblem currently supports only QuadraticTemplate"))

    A = mode_matrices(problem.system)
    _check_safety_data(graph, A, problem)

    node_list = collect(nodes(graph))
    n_nodes = length(node_list)

    node_index = Dict(v => i for (i, v) in enumerate(node_list))

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    n = size(first(A), 1)
    d = n + 1

    # Barrier matrices: symmetric but sign-free, so no PSD constraint here --
    # requiring it leaves P = 0 as the only solution.
    Ps = [add_function_variables!(model, template, d, i) for i in 1:n_nodes]

    # Initial-set and unsafe-set multipliers
    gamma0 =
        [JuMP.@variable(model, lower_bound = 0, base_name = "gamma0_$i") for i in 1:n_nodes]

    gammau =
        [JuMP.@variable(model, lower_bound = 0, base_name = "gammau_$i") for i in 1:n_nodes]

    eps = JuMP.@variable(model, lower_bound = 0, base_name = "eps")

    # Initial-set and unsafe-set constraints
    for v in node_list
        i = node_index[v]

        JuMP.@constraint(
            model,
            -(Ps[i] + gamma0[i] * problem.S0) - eps * LinearAlgebra.I(d) in JuMP.PSDCone()
        )

        JuMP.@constraint(
            model,
            Ps[i] - gammau[i] * problem.Su - eps * LinearAlgebra.I(d) in JuMP.PSDCone()
        )
    end

    # Transition constraints
    for edge in edges(graph)
        i = node_index[source(edge)]
        j = node_index[target(edge)]

        add_edge_constraint!(model, problem, template, Ps[i], Ps[j], A[label(edge)], eps)
    end

    JuMP.@objective(model, Max, eps)

    # Store variables for result extraction
    model[:safety_P] = Ps
    model[:safety_gamma0] = gamma0
    model[:safety_gammau] = gammau
    model[:safety_eps] = eps
    model[:safety_nodes] = node_list

    return model
end

"""
    safety_certificate(template, graph, problem; optimizer)

Solve the path-complete barrier optimization problem.
"""
function safety_certificate(
    template::Type{<:AbstractTemplate},
    graph::Graph,
    problem::SafetyProblem;
    optimizer,
)
    model = safety_problem(template, graph, problem; optimizer = optimizer)

    JuMP.optimize!(model)

    status = JuMP.termination_status(model)

    if !(status in _FEASIBLE_TERMINATION_STATUSES)
        return (
            status = status,
            P = nothing,
            gamma0 = nothing,
            gammau = nothing,
            eps = nothing,
            feasible = false,
        )
    end

    Ps = model[:safety_P]
    gamma0 = model[:safety_gamma0]
    gammau = model[:safety_gammau]
    eps = model[:safety_eps]

    Pval = [JuMP.value.(P) for P in Ps]
    gamma0_val = JuMP.value.(gamma0)
    gammau_val = JuMP.value.(gammau)
    eps_val = JuMP.value(eps)

    # Check the initial-set and unsafe-set constraints
    feas = true

    for i in eachindex(Pval)
        initial_margin = LinearAlgebra.Symmetric(-(Pval[i] + gamma0_val[i] * problem.S0))

        unsafe_margin = LinearAlgebra.Symmetric(Pval[i] - gammau_val[i] * problem.Su)

        if minimum(LinearAlgebra.eigvals(initial_margin)) < eps_val - 1e-7 ||
           minimum(LinearAlgebra.eigvals(unsafe_margin)) < eps_val - 1e-7
            feas = false
            break
        end
    end

    return (
        status = status,
        P = Pval,
        gamma0 = gamma0_val,
        gammau = gammau_val,
        eps = eps_val,
        feasible = feas && eps_val > -1e-7,
    )
end

"""
    _homogeneous_dynamics(A)

Return the homogeneous-coordinate representation of x⁺ = A*x.
"""
function _homogeneous_dynamics(A::AbstractMatrix)
    n = size(A, 1)

    return [
        A zeros(n, 1)
        zeros(1, n) 1.0
    ]
end

function _check_safety_data(
    graph::Graph,
    A::AbstractVector{<:AbstractMatrix},
    problem::SafetyProblem,
)
    isempty(A) && throw(ArgumentError("at least one mode is required"))

    n = size(first(A), 1)

    n > 0 || throw(ArgumentError("mode matrices must have positive dimension"))

    for (i, A_i) in enumerate(A)
        size(A_i) == (n, n) ||
            throw(ArgumentError("A[$i] has size $(size(A_i)); expected ($n, $n)"))
    end

    for edge in edges(graph)
        1 <= label(edge) <= length(A) ||
            throw(ArgumentError("edge label $(label(edge)) does not index a mode in A"))
    end

    return nothing
end

"""
    barrier(P, x)

Evaluate the quadratic barrier function

    B(x) = [x; 1]' * P * [x; 1].
"""
function barrier(P::AbstractMatrix, x::AbstractVector{<:Real})
    z = [x; 1.0]
    return LinearAlgebra.dot(z, P * z)
end

"""
    CoBF_complete(Ps, x)

Evaluate the common barrier function associated with a complete graph.
"""
function CoBF_complete(Ps::AbstractVector{<:AbstractMatrix}, x::AbstractVector{<:Real})
    return minimum(barrier(P, x) for P in Ps)
end

"""
    CoBF_co_complete(Ps, x)

Evaluate the common barrier function associated with a co-complete graph.
"""
function CoBF_co_complete(Ps::AbstractVector{<:AbstractMatrix}, x::AbstractVector{<:Real})
    return maximum(barrier(P, x) for P in Ps)
end

"""
    CoBF(Ps, obs_states, x)

Evaluate the common barrier function associated with a general graph.

obs_states contains the sets of nodes corresponding to the observation
classes. The node identifiers must correspond to indices in Ps.
"""
function CoBF(
    Ps::AbstractVector{<:AbstractMatrix},
    obs_states::AbstractVector{<:AbstractSet{<:Integer}},
    x::AbstractVector{<:Real},
)
    vals = [maximum(barrier(Ps[v], x) for v in S) for S in obs_states]

    return minimum(vals)
end

export SafetyProblem, safety_problem, safety_certificate
export barrier, CoBF, CoBF_complete, CoBF_co_complete
