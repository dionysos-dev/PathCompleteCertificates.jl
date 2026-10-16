"""
    Trajectory

One run of a switched system: the states visited, the switching sequence taken
and the inputs applied, `nothing` if there were none. Its `length` is the
number of steps.
"""
struct Trajectory{T <: Real, U <: Union{Nothing, Vector{Vector{T}}}}
    states::Vector{Vector{T}}
    switching::Vector{Int}
    inputs::U

    # Inner, so that no default constructor bypasses the shape checks.
    function Trajectory(
        states::AbstractVector{<:AbstractVector},
        switching::AbstractVector{<:Integer},
        inputs::Union{Nothing, AbstractVector{<:AbstractVector}},
    )
        length(states) == length(switching) + 1 || throw(
            ArgumentError(
                "a trajectory needs one more state than steps: got " *
                "$(length(states)) states for $(length(switching)) steps",
            ),
        )
        _check_same_length(states, "state")
        all(>=(1), switching) ||
            throw(ArgumentError("modes are numbered from 1, got $switching"))

        if inputs !== nothing
            length(inputs) == length(switching) || throw(
                ArgumentError(
                    "got $(length(inputs)) inputs for $(length(switching)) steps",
                ),
            )
            _check_same_length(inputs, "input")
        end

        # One element type for everything, wide enough for all
        T = mapreduce(eltype, promote_type, inputs === nothing ? states : [states; inputs])
        visited = Vector{T}[convert(Vector{T}, x) for x in states]
        applied =
            inputs === nothing ? nothing : Vector{T}[convert(Vector{T}, u) for u in inputs]

        return new{T, typeof(applied)}(visited, collect(Int, switching), applied)
    end
end

"""
    states(trajectory)

The states visited, oldest first, one more than the steps.
"""
states(trajectory::Trajectory) = trajectory.states

"""
    switching(trajectory)

The modes taken: entry `k` carried `states(trajectory)[k]` to
`states(trajectory)[k + 1]`.
"""
switching(trajectory::Trajectory) = trajectory.switching

"""
    inputs(trajectory)

The inputs applied, one per step, or `nothing` for an open-loop run.
"""
inputs(trajectory::Trajectory) = trajectory.inputs

"""
    has_input(trajectory) -> Bool

Whether the run applied an input.
"""
has_input(trajectory::Trajectory) = trajectory.inputs !== nothing

Base.length(trajectory::Trajectory) = length(trajectory.switching)

function _check_same_length(vectors, what::AbstractString)
    isempty(vectors) && return nothing
    n = length(first(vectors))
    all(v -> length(v) == n, vectors) ||
        throw(ArgumentError("every $what must have length $n, got $(length.(vectors))"))
    return nothing
end
