"""
    simulate(system, x0, modes; u = nothing)
    simulate(system, x0, horizon::Integer; u = nothing, rng = Random.default_rng())

Run `system` from `x0` along `modes`, or along `horizon` modes drawn uniformly
at random, and return a
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

    _check_initial_state(system, x0)
    input = controlled ? (k, x) -> _input_at(u, k, x) : nothing

    return _run(system, x0, modes, input)
end

function simulate(
    system::_HS.HybridSystem,
    x0::AbstractVector,
    horizon::Integer;
    u = nothing,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    return simulate(system, x0, _random_modes(rng, system, horizon); u = u)
end

_input_at(u::AbstractVector, k, x) = u[k]
_input_at(u, k, x) = u(x)

function _check_initial_state(system::_HS.HybridSystem, x0::AbstractVector)
    n = size(first(mode_matrices(system)), 1)
    length(x0) == n ||
        throw(ArgumentError("x0 has length $(length(x0)), expected $n to match the system"))
    return nothing
end

function _random_modes(rng::Random.AbstractRNG, system::_HS.HybridSystem, horizon::Integer)
    horizon >= 0 || throw(ArgumentError("horizon must be nonnegative, got $horizon"))
    return rand(rng, 1:n_modes(system), horizon)
end

# The run from `x0` along `modes`: `x⁺ = A_σ x`, or `x⁺ = A_σ x + B_σ u` with
# `u = input(k, x)` at step `k` when `input` is given. Each step keeps the type
# its arithmetic gives, and the run is promoted once at the end, so an integer
# system driven by a real input works and an exact run stays exact.
function _run(system::_HS.HybridSystem, x0::AbstractVector, modes, input)
    A = mode_matrices(system)
    B = input === nothing ? nothing : input_matrices(system)

    xs = AbstractVector[x0]
    us = AbstractVector[]

    for (k, σ) in enumerate(modes)
        x = xs[k]

        if input === nothing
            push!(xs, A[σ] * x)
        else
            push!(us, input(k, x))
            push!(xs, A[σ] * x + B[σ] * us[k])
        end
    end

    T = mapreduce(eltype, promote_type, [xs; us]; init = eltype(first(A)))
    states = Vector{T}[convert(Vector{T}, x) for x in xs]
    inputs = input === nothing ? nothing : Vector{T}[convert(Vector{T}, u) for u in us]

    return Trajectory(states, modes, inputs)
end
