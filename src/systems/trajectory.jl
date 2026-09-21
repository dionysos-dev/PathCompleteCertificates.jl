"""
    Trajectory

One run of a switched system: the states visited, the switching sequence taken,
and the inputs applied if there were any.

`states` holds one more entry than `switching` — it starts at the initial state
and ends after the last transition. `inputs` is `nothing` for an open-loop run,
and otherwise holds one input per step.

The sequence is called `switching`, not `modes`: `alphabet` is the set of modes
a system or graph has, and this is a word over it.
"""
struct Trajectory{T <: Real, U <: Union{Nothing, Vector{Vector{T}}}}
    states::Vector{Vector{T}}
    switching::Vector{Int}
    inputs::U

    # Inner, so the default constructors are not generated alongside it: an
    # outer method of the same signature would merely overwrite one of them,
    # and a trajectory of the wrong shape must not be constructible at all.
    function Trajectory(
        states::AbstractVector{<:AbstractVector{T}},
        switching::AbstractVector{<:Integer},
        inputs::Union{Nothing, AbstractVector{<:AbstractVector{T}}},
    ) where {T <: Real}
        length(states) == length(switching) + 1 || throw(
            ArgumentError(
                "a trajectory needs one more state than steps: got " *
                "$(length(states)) states for $(length(switching)) steps",
            ),
        )

        inputs === nothing ||
            length(inputs) == length(switching) ||
            throw(
                ArgumentError(
                    "got $(length(inputs)) inputs for $(length(switching)) steps",
                ),
            )

        visited = Vector{T}[convert(Vector{T}, x) for x in states]
        applied =
            inputs === nothing ? nothing : Vector{T}[convert(Vector{T}, u) for u in inputs]

        return new{T, typeof(applied)}(visited, collect(Int, switching), applied)
    end
end

"""
    states(trajectory)

The states visited, oldest first. One longer than [`switching`](@ref).
"""
states(trajectory::Trajectory) = trajectory.states

"""
    switching(trajectory)

The switching sequence taken, as modes. One shorter than [`states`](@ref):
entry `k` is the mode that carried `states(trajectory)[k]` to
`states(trajectory)[k + 1]`.
"""
switching(trajectory::Trajectory) = trajectory.switching

"""
    inputs(trajectory)

The inputs applied, one per step, or `nothing` for an open-loop run. Guard with
[`has_input`](@ref) rather than comparing to `nothing` at the call site.
"""
inputs(trajectory::Trajectory) = trajectory.inputs

"""
    has_input(trajectory) -> Bool

Whether the run applied an input. Mirrors `has_input` on a system, so the same
word answers the same question on both.
"""
has_input(trajectory::Trajectory) = trajectory.inputs !== nothing

# The number of steps, which is one fewer than the number of states. Left
# undocumented on purpose: `checkdocs = :all` would then demand a manual entry
# for a `Base` binding we merely extend.
Base.length(trajectory::Trajectory) = length(trajectory.switching)
