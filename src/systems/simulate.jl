import Random

# Simulation is here because `refute` will be built on it: sampling runs is the
# cheap way to learn you are wrong. Nothing in this file certifies anything,
# which is why it sits with the systems rather than the problems.
#
# The plant's switching automaton is walked through the HybridSystems API rather
# than through `graphs/queries.jl`. Those queries are for the *certificate*
# graph; `out_transitions` works uniformly here on both `OneStateAutomaton` (a
# system with free switching) and `GraphAutomaton` (a constrained one), which
# `graphs/queries.jl` does not.

"""
    simulate(system, x0, steps; rng = Random.default_rng(), switching_state = ...)
    simulate(system, x0, switching)
    simulate(certificate, x0, steps; rng = Random.default_rng(), node = 1)

Run `system` from `x0` and return a [`Trajectory`](@ref).

Given an integer `steps`, the mode at each step is drawn uniformly **from the
modes the system's switching automaton admits**, not from `1:n`. A system built
with `switched_system(A; automaton = ...)` restricts which sequences are
possible, and a simulation that ignored that would produce runs the plant
cannot take. `switching_state` is where that automaton starts; it only matters
for a constrained system.

Given a vector `switching` instead, that exact sequence is taken, and an
inadmissible one throws rather than being silently adjusted. Prefer this in
tests: Julia's default random stream is not stable across releases.

Given a certificate, the loop is closed — see the method below.

```julia
system = switched_system([[0.5 0.0; 0.0 0.25]])
simulate(system, [1.0, 1.0], 10)
```
"""
function simulate end

function simulate(
    system::_HS.HybridSystem,
    x0::AbstractVector{<:Real},
    steps::Integer;
    rng::Random.AbstractRNG = Random.default_rng(),
    switching_state::Integer = first(_HS.states(system.automaton)),
)
    steps >= 0 || throw(ArgumentError("steps must be nonnegative, got $steps"))

    A = _open_loop_matrices(system, x0)

    word = Int[]
    state = switching_state

    for step in 1:steps
        admissible = collect(_HS.out_transitions(system.automaton, state))

        isempty(admissible) && throw(
            ArgumentError(
                "the switching automaton admits no mode from state $state, " *
                "reached after $(step - 1) steps",
            ),
        )

        transition = rand(rng, admissible)
        push!(word, _HS.event(system.automaton, transition))
        state = _HS.target(system.automaton, transition)
    end

    return _run(A, x0, word)
end

function simulate(
    system::_HS.HybridSystem,
    x0::AbstractVector{<:Real},
    word::AbstractVector{<:Integer};
    switching_state::Integer = first(_HS.states(system.automaton)),
)
    A = _open_loop_matrices(system, x0)

    _check_admissible(system.automaton, word, switching_state)

    for (step, mode) in enumerate(word)
        mode in eachindex(A) || throw(
            ArgumentError(
                "step $step asks for mode $mode; the system has " * "$(length(A)) of them",
            ),
        )
    end

    return _run(A, x0, collect(Int, word))
end

"""
    simulate(certificate, x0, steps; rng = Random.default_rng(), node = 1)

Run the closed loop under the state-feedback policy a
[`OptimalControlCertificate`](@ref) carries, and return a [`Trajectory`](@ref)
whose [`inputs`](@ref) are the inputs applied.

!!! note "The policy has memory"
    The gains are indexed by **node of the certificate graph**, not by mode, so
    `u = K x` is not the whole story: the node advances along the observed mode,
    and which gain applies depends on where in the graph the run currently is.
    That is what the graph buys — a controller that remembers as much of the
    switching history as the graph does.

    `node` is where it starts. Where the graph offers several successors for the
    observed mode, the first is taken; on a De Bruijn graph the successor is
    unique, so this does not arise.
"""
function simulate(
    certificate::OptimalControlCertificate,
    x0::AbstractVector{<:Real},
    steps::Integer;
    rng::Random.AbstractRNG = Random.default_rng(),
    node::Integer = 1,
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

    _check_node(certificate_graph, node)

    A = mode_matrices(system)
    B = input_matrices(system)
    _check_initial_state(x0, A)

    T = promote_type(eltype(x0), eltype(first(A)), eltype(first(B)), eltype(first(gains)))

    x = convert(Vector{T}, collect(x0))
    visited = [x]
    applied = Vector{T}[]
    word = Int[]

    state = first(_HS.states(system.automaton))

    for step in 1:steps
        admissible = collect(_HS.out_transitions(system.automaton, state))

        isempty(admissible) && throw(
            ArgumentError(
                "the switching automaton admits no mode from state $state, " *
                "reached after $(step - 1) steps",
            ),
        )

        transition = rand(rng, admissible)
        mode = _HS.event(system.automaton, transition)

        u = gains[node] * x
        x = A[mode] * x + B[mode] * u

        push!(applied, u)
        push!(visited, x)
        push!(word, mode)

        state = _HS.target(system.automaton, transition)
        node = _successor(certificate_graph, node, mode)
    end

    return Trajectory(visited, word, applied)
end

"The state matrices, having checked the system and the initial state suit an open-loop run."
function _open_loop_matrices(system::_HS.HybridSystem, x0::AbstractVector{<:Real})
    has_input(system) && throw(
        ArgumentError(
            "the system has an input, so an open-loop run is underdetermined. " *
            "Pass an OptimalControlCertificate to simulate the closed loop",
        ),
    )

    A = mode_matrices(system)
    _check_initial_state(x0, A)

    return A
end

function _check_initial_state(x0::AbstractVector{<:Real}, A)
    n = size(first(A), 1)
    length(x0) == n ||
        throw(ArgumentError("x0 has length $(length(x0)), expected $n to match the system"))

    return nothing
end

"Walk `word` through `automaton`, throwing at the first step it cannot take."
function _check_admissible(automaton, word, state)
    for (step, mode) in enumerate(word)
        transition = nothing

        for candidate in _HS.out_transitions(automaton, state)
            if _HS.event(automaton, candidate) == mode
                transition = candidate
                break
            end
        end

        transition === nothing && throw(
            ArgumentError(
                "mode $mode is not admissible at step $step: the switching " *
                "automaton is in state $state, which does not offer it",
            ),
        )

        state = _HS.target(automaton, transition)
    end

    return nothing
end

"The node the certificate graph moves to when `mode` is observed at `node`."
function _successor(certificate_graph, node::Integer, mode::Integer)
    candidates = outgoing_edges(certificate_graph, node, mode)

    isempty(candidates) && throw(
        ArgumentError(
            "the certificate graph has no edge labelled $mode out of node $node, " *
            "so the policy has nowhere to go. The graph is not complete for " *
            "this system's alphabet",
        ),
    )

    return dest(first(candidates))
end

"Apply `word` from `x0` under the open-loop dynamics `A`."
function _run(A, x0::AbstractVector{<:Real}, word::Vector{Int})
    T = promote_type(eltype(x0), eltype(first(A)))

    x = convert(Vector{T}, collect(x0))
    visited = [x]

    for mode in word
        x = A[mode] * x
        push!(visited, x)
    end

    return Trajectory(visited, word, nothing)
end
