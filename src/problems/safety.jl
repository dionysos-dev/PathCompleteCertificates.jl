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

    function SafetyProblem(system::S, S0::AbstractMatrix, Su::AbstractMatrix) where {S}
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

# One method, generic over templates, exactly as for stability. Safety differs
# from stability in one argument: the dynamics are lifted to homogeneous
# coordinates. The edge condition is `B_dst(A x) <= B_src(x)` -- non-increasing,
# with no margin.
#
# A margin here is not merely unnecessary, it is unsatisfiable. In homogeneous
# coordinates the constant direction e = [0, ..., 0, 1] is fixed by every lifted
# map, so the edge condition read at e says P_src[end, end] >= P_dst[end, end] +
# margin. Summed around any cycle the left and right sides telescope to the same
# value, giving 0 >= L * margin -- so on any graph with a cycle, which is every
# path-complete graph, the margin can only be zero. Asking for one made
# `max margin` optimise nothing and reduced `feasible` to "the solver
# converged". Separation between the initial and unsafe sets is what needs to be
# strict, and that is imposed in `safety_problem` where it can be.
function add_edge_constraint!(
    model::JuMP.Model,
    problem::SafetyProblem,
    template::AbstractTemplate,
    P_src,
    P_dst,
    A::AbstractMatrix,
    _unused,
)
    add_domination!(model, template, P_src, P_dst, _homogeneous_dynamics(A); scale = 1)

    return nothing
end

"""
    safety_problem(template, graph, problem; optimizer)

Construct the path-complete barrier optimization model.
"""
function safety_problem(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::SafetyProblem;
    optimizer,
)
    template isa QuadraticTemplate ||
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

    # The separation margin: how strictly the barrier is negative on the initial
    # set and positive on the unsafe one. This is where strictness belongs --
    # see `add_edge_constraint!` for why it cannot go on the transitions.
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

        # Every other constraint is homogeneous of degree one in (P, gamma, eps),
        # so without a scale `max eps` is unbounded whenever it is positive at
        # all. Fixing the scale of the barriers makes eps a comparable number --
        # the margin achievable per unit of barrier -- rather than an arbitrary
        # one, and it costs nothing: any feasible family can be scaled into this
        # box.
        JuMP.@constraint(model, LinearAlgebra.I(d) - Ps[i] in JuMP.PSDCone())
        JuMP.@constraint(model, Ps[i] + LinearAlgebra.I(d) in JuMP.PSDCone())
    end

    # Transition constraints
    for edge in edges(graph)
        i = node_index[source(edge)]
        j = node_index[dest(edge)]

        add_edge_constraint!(
            model,
            problem,
            template,
            Ps[i],
            Ps[j],
            A[label(graph, edge)],
            eps,
        )
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
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
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

    # Re-check the S-procedure conditions on the returned numbers rather than
    # trusting the status, and require a strictly positive separation: `eps = 0`
    # means the barrier only just fails to distinguish the two sets, which
    # certifies nothing.
    feas = eps_val > _SAFETY_MARGIN_TOLERANCE

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
        feasible = feas,
    )
end

"""
    _SAFETY_MARGIN_TOLERANCE

How positive the separation margin has to be before a barrier counts as one.

Not a numerical fudge: `eps` is a genuine quantity now that the barriers are
scale-normalised, so a value at solver noise means the initial and unsafe sets
were not separated.
"""
const _SAFETY_MARGIN_TOLERANCE = 1e-8

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
    graph::_HS.GraphAutomaton,
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
        edge_label = label(graph, edge)
        1 <= edge_label <= length(A) ||
            throw(ArgumentError("edge label $edge_label does not index a mode in A"))
    end

    _check_path_complete(graph, length(A))

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

function _node_value(
    ::QuadraticTemplate,
    ::SafetyProblem,
    P::AbstractMatrix,
    x::AbstractVector{<:Real},
)
    return barrier(P, x)
end
