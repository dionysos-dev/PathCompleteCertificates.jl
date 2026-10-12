import Random

"""
    simulate(system, x0, modes; u = nothing)
    simulate(system, x0, horizon::Integer; u = nothing, discrete_state = 1, rng = Random.default_rng())

Run `system` from `x0` along `modes`, or along a uniform random walk of length
`horizon` on its automaton from `discrete_state`, and return a
[`Trajectory`](@ref). `u`, a vector of inputs or a feedback law `u(x)`, is
required exactly when [`has_input`](@ref)`(system)`; otherwise it throws.
"""
function simulate(
    system::_HS.HybridSystem,
    x0::AbstractVector,
    modes::AbstractVector{<:Integer};
    u = nothing,
)
    controlled = has_input(system)
    controlled == (u !== nothing) || throw(
        ArgumentError(
            controlled ? "system has an input; `u` is required" :
            "system has no input; `u` must not be given",
        ),
    )

    A = mode_matrices(system)
    B = controlled ? input_matrices(system) : nothing

    n = size(first(A), 1)
    length(x0) == n ||
        throw(ArgumentError("x0 has length $(length(x0)), expected $n to match the system"))

    # Promoted so that an integer `x0` under real dynamics does not throw.
    T = promote_type(eltype(x0), eltype(first(A)), controlled ? eltype(first(B)) : Bool)

    xs = Vector{Vector{T}}(undef, length(modes) + 1)
    xs[1] = convert(Vector{T}, x0)
    us = controlled ? Vector{Vector{T}}(undef, length(modes)) : nothing

    for k in eachindex(modes)
        σ = modes[k]
        x = xs[k]

        if controlled
            us[k] = convert(Vector{T}, _input_at(u, k, x))
            xs[k + 1] = A[σ] * x + B[σ] * us[k]
        else
            xs[k + 1] = A[σ] * x
        end
    end

    return Trajectory(xs, modes, us)
end

function simulate(
    system::_HS.HybridSystem,
    x0::AbstractVector,
    horizon::Integer;
    u = nothing,
    discrete_state::Integer = 1,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    modes = _random_modes(system.automaton, discrete_state, horizon, rng)

    return simulate(system, x0, modes; u = u)
end

_input_at(u::AbstractVector, k, x) = u[k]
_input_at(u, k, x) = u(x)

function _random_modes(automaton, node::Integer, horizon::Integer, rng::Random.AbstractRNG)
    modes = Vector{Int}(undef, horizon)
    for k in 1:horizon
        # Not `outgoing_edges`, which rejects a `OneStateAutomaton`.
        options = collect(_HS.out_transitions(automaton, node))
        isempty(options) && throw(
            ArgumentError(
                "node $node has no outgoing transition; the switching " *
                "sequence cannot be continued",
            ),
        )
        transition = rand(rng, options)
        modes[k] = _HS.event(automaton, transition)
        node = _HS.target(automaton, transition)
    end
    return modes
end
