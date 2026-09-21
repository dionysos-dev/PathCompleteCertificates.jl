import Random

"""
    simulate(system, x0, modes; u = nothing)
    simulate(system, x0, horizon::Integer; u = nothing, node = 1, rng = Random.default_rng())

Run `system` from `x0` along a switching sequence and return a
[`Trajectory`](@ref): `x[k+1] = A_{modes[k]} x[k]`, or, once `system` has an
input, `x[k+1] = A_{modes[k]} x[k] + B_{modes[k]} u[k]`.

Given `modes` explicitly, that sequence is taken. Prefer this in a test —
Julia's default random stream is not stable across releases.

Given a `horizon` instead, a sequence of that length is drawn: a random walk on
`system`'s automaton, starting at discrete state `node` and, at each step,
picking uniformly among the transitions leaving the current state. A system
built with a restricted `automaton` therefore only ever produces a sequence
that automaton admits, never an inadmissible one.

Both return the same type, so the drawn sequence is read back off the result
with [`switching`](@ref) rather than returned alongside it.

`u` is required exactly when [`has_input`](@ref)`(system)`; passing one for an
autonomous system, or omitting it for a controlled one, throws. It is either a
sequence of inputs, as long as the switching sequence and indexed like it, or a
*memoryless* feedback law `u(x)`, called on the current state at each step.

An [`OptimalControlCertificate`](@ref) policy is not memoryless, so it is not
one of these: its gains are indexed by node of the certificate graph, and that
node advances along the observed mode. A `u(x)` closure is never told the mode,
so it cannot follow the graph — written naively it applies the starting node's
gain forever, which is not the policy the certificate certifies.
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

    # Promoted, not `typeof(x0)`: an integer `x0` under real dynamics is the
    # obvious call, and storing the result back into a `Vector{Int}` would throw
    # an `InexactError` from the second step.
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
    node::Integer = 1,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    return simulate(system, x0, _random_modes(system.automaton, node, horizon, rng); u = u)
end

_input_at(u::AbstractVector, k, x) = u[k]
_input_at(u, k, x) = u(x)

"A random walk on `automaton`, `horizon` labels long, starting from `node`."
function _random_modes(automaton, node::Integer, horizon::Integer, rng::Random.AbstractRNG)
    modes = Vector{Int}(undef, horizon)
    for k in 1:horizon
        # Not `outgoing_edges`: those queries are the adapter over
        # `GraphAutomaton`, the type a *certificate* graph has. The automaton of
        # a system built without a restriction is a `OneStateAutomaton`, which
        # they do not accept. The HybridSystems walk works on both.
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
