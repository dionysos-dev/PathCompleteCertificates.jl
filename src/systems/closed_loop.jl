# Apart from `simulate.jl` because it depends on the certificate types.

"""
    simulate(certificate, x0, steps; rng = Random.default_rng(), node = nothing)

Run the closed loop under the policy of `certificate` along a random admissible
switching sequence, and return a [`Trajectory`](@ref). The gain applied is that
of the current graph node, which follows the observed modes from `node`, by
default the node whose function is smallest at `x0`.
"""
function simulate(
    certificate::OptimalControlCertificate,
    x0::AbstractVector{<:Real},
    steps::Integer;
    rng::Random.AbstractRNG = Random.default_rng(),
    node::Union{Nothing, Integer} = nothing,
)
    steps >= 0 || throw(ArgumentError("steps must be nonnegative, got $steps"))

    is_feasible(certificate) || throw(
        ArgumentError(
            "the certificate is infeasible ($(status(certificate))), so it " *
            "carries no policy to simulate",
        ),
    )

    system = problem(certificate).system
    certificate_graph = graph(certificate)
    gains = certificate.gains

    A = mode_matrices(system)
    B = input_matrices(system)

    n = size(first(A), 1)
    length(x0) == n ||
        throw(ArgumentError("x0 has length $(length(x0)), expected $n to match the system"))

    node = something(node, argmin([V(x0) for V in functions(certificate)]))
    _check_node(certificate_graph, node)

    modes = _random_modes(system.automaton, first(_HS.states(system.automaton)), steps, rng)

    T = promote_type(eltype(x0), eltype(first(A)), eltype(first(B)), eltype(first(gains)))

    xs = Vector{Vector{T}}(undef, steps + 1)
    us = Vector{Vector{T}}(undef, steps)
    xs[1] = convert(Vector{T}, x0)

    for k in 1:steps
        σ = modes[k]
        x = xs[k]

        us[k] = gains[node] * x
        xs[k + 1] = A[σ] * x + B[σ] * us[k]

        node = _successor(certificate_graph, node, σ)
    end

    return Trajectory(xs, modes, us)
end

# The node the certificate graph moves to when `mode` is observed at `node`.
function _successor(certificate_graph, node::Integer, mode::Integer)
    candidates = outgoing_edges(certificate_graph, node, mode)

    isempty(candidates) && throw(
        ArgumentError(
            "the certificate graph has no edge labelled $mode out of node $node, " *
            "so the policy has nowhere to go: the graph is not complete for " *
            "this system's alphabet",
        ),
    )

    return dest(first(candidates))
end
