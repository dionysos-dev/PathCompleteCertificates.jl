import Random

"""
    simulate(system, x0, modes; u = nothing)
    simulate(system, x0, horizon::Integer; u = nothing, node = 1, rng = Random.default_rng())

The state trajectory of `system` starting at `x0`, along a switching sequence:
`x[k+1] = A_{modes[k]} x[k]`, or, once `system` has an input,
`x[k+1] = A_{modes[k]} x[k] + B_{modes[k]} u[k]`.

Given `modes` explicitly, returns the trajectory alone -- a `Vector` of
states, `length(modes) + 1` long, `x0` first.

Given a `horizon` instead, a switching sequence of that length is drawn: a
random walk on `system`'s automaton, starting at discrete state `node` and,
at each step, picking uniformly among the transitions leaving the current
state. A system built with a restricted `automaton` therefore only ever
produces a sequence that automaton admits, never an inadmissible one. Since
the sequence is not the caller's to know in advance, this method returns
`(xs, modes)` -- the trajectory together with the sequence that generated it.

`u` is required exactly when [`has_input`](@ref)`(system)`; passing one for an
autonomous system, or omitting it for a controlled one, throws. It is either a
sequence of inputs, as long as the switching sequence and indexed like it, or
a feedback law `u(x)` called on the current state at each step -- a closure
over an [`OptimalControlCertificate`](@ref)'s `gains` is the common case, but
nothing here is specific to that certificate.
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

    xs = Vector{typeof(x0)}(undef, length(modes) + 1)
    xs[1] = x0
    for k in eachindex(modes)
        σ = modes[k]
        x = xs[k]
        xs[k + 1] = controlled ? A[σ] * x + B[σ] * _input_at(u, k, x) : A[σ] * x
    end

    return xs
end

function simulate(
    system::_HS.HybridSystem,
    x0::AbstractVector,
    horizon::Integer;
    u = nothing,
    node::Integer = 1,
    rng::Random.AbstractRNG = Random.default_rng(),
)
    modes = _random_modes(system.automaton, node, horizon, rng)
    return simulate(system, x0, modes; u = u), modes
end

_input_at(u::AbstractVector, k, x) = u[k]
_input_at(u, k, x) = u(x)

"A random walk on `automaton`, `horizon` labels long, starting from `node`."
function _random_modes(automaton, node::Integer, horizon::Integer, rng::Random.AbstractRNG)
    modes = Vector{Int}(undef, horizon)
    for k in 1:horizon
        options = outgoing_edges(automaton, node)
        isempty(options) && throw(
            ArgumentError(
                "node $node has no outgoing transition; the switching " *
                "sequence cannot be continued",
            ),
        )
        transition = rand(rng, options)
        modes[k] = label(automaton, transition)
        node = dest(transition)
    end
    return modes
end
