# The closed loop, kept apart from `simulate.jl` because it is the one part of
# simulation that depends on the problem axis: it dispatches on a certificate.

"""
    simulate(certificate, x0, steps; rng = Random.default_rng(), node = nothing)

Run the closed loop under the policy an [`OptimalControlCertificate`](@ref)
carries, and return a [`Trajectory`](@ref) whose [`inputs`](@ref) are the
inputs applied. The mode at each step is drawn from the modes the system's
automaton admits, as in the open-loop method.

The policy has memory: the gains are indexed by node of the certificate graph,
and that node advances along the observed mode, so the run tracks the state,
the automaton state and the graph node at once. A memoryless law `u(x)` cannot
express it, which is why it is not the `u` keyword of the open-loop method.

`node` is the node of the certificate graph the policy starts in. By default it
is the node whose function attains `certificate(x0)`, so the run is bounded by
the common bound at the initial state. Where the graph offers several
successors for the observed mode the first is taken; on a De Bruijn graph the
successor is unique.
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
