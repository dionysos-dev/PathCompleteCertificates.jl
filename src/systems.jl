import MathematicalSystems as MS

"""
    AbstractSwitchedSystem

A discrete-time switched linear system: `x⁺` is driven by `A_σ` where the mode
`σ` is chosen by the environment, not by us.

Subtypes differ only in whether there is a control input.
"""
abstract type AbstractSwitchedSystem <: MS.AbstractSystem end

"""
    SwitchedLinearSystem(A; constraint = nothing)

`x⁺ = A_σ x`, with `A` indexed by mode.

`constraint` is a labelled digraph restricting which switching sequences are
admissible; `nothing` means arbitrary switching.
"""
struct SwitchedLinearSystem{T <: Real, C} <: AbstractSwitchedSystem
    A::Vector{Matrix{T}}
    constraint::C

    function SwitchedLinearSystem(A::AbstractVector{<:AbstractMatrix}; constraint = nothing)
        T = _check_square(A)
        return new{T, typeof(constraint)}([Matrix{T}(Aσ) for Aσ in A], constraint)
    end
end

"""
    SwitchedLinearControlSystem(A, B; constraint = nothing)

`x⁺ = A_σ x + B_σ u`, with `A` and `B` indexed by mode.

The mode is not ours to choose; the input is. See [`SwitchedLinearSystem`](@ref)
for `constraint`.
"""
struct SwitchedLinearControlSystem{T <: Real, C} <: AbstractSwitchedSystem
    A::Vector{Matrix{T}}
    B::Vector{Matrix{T}}
    constraint::C

    function SwitchedLinearControlSystem(
        A::AbstractVector{<:AbstractMatrix},
        B::AbstractVector{<:AbstractMatrix};
        constraint = nothing,
    )
        T = _check_square(A)
        _check_inputs(A, B)
        S = promote_type(T, eltype(first(B)))
        return new{S, typeof(constraint)}(
            [Matrix{S}(Aσ) for Aσ in A],
            [Matrix{S}(Bσ) for Bσ in B],
            constraint,
        )
    end
end

"""
    nmodes(system) -> Int

Number of modes, i.e. the size of the switching alphabet.
"""
nmodes(system::AbstractSwitchedSystem) = length(state_matrices(system))

"""
    modes(system)

The modes of `system`, `1:nmodes(system)`.
"""
modes(system::AbstractSwitchedSystem) = Base.OneTo(nmodes(system))

"""
    statedim(system) -> Int

Dimension of the state.
"""
MS.statedim(system::AbstractSwitchedSystem) = size(first(state_matrices(system)), 1)

"""
    inputdim(system) -> Int

Dimension of the control input.
"""
MS.inputdim(system::SwitchedLinearControlSystem) = size(first(input_matrices(system)), 2)

"""
    state_matrices(system)

All the `A_σ`, indexed by mode. The system's own storage, not a copy.
"""
state_matrices(system::AbstractSwitchedSystem) = system.A

"""
    input_matrices(system)

All the `B_σ`, indexed by mode. The system's own storage, not a copy.
"""
input_matrices(system::SwitchedLinearControlSystem) = system.B

"""
    state_matrix(system, σ)

`A_σ`, the state matrix of mode `σ`.
"""
MS.state_matrix(system::AbstractSwitchedSystem, σ::Integer) = state_matrices(system)[σ]

"""
    input_matrix(system, σ)

`B_σ`, the input matrix of mode `σ`.
"""
MS.input_matrix(system::SwitchedLinearControlSystem, σ::Integer) = input_matrices(system)[σ]

"""
    iscontrolled(system) -> Bool

Whether the dynamics contain a control input `u`.
"""
MS.iscontrolled(::SwitchedLinearSystem) = false
MS.iscontrolled(::SwitchedLinearControlSystem) = true

MS.islinear(::AbstractSwitchedSystem) = true
MS.isaffine(::AbstractSwitchedSystem) = true
MS.isnoisy(::AbstractSwitchedSystem) = false
MS.isconstrained(::AbstractSwitchedSystem) = false

"""
    constraint(system)

The switching constraint, or `nothing` under arbitrary switching.
"""
constraint(system::AbstractSwitchedSystem) = system.constraint

function _check_square(A)
    isempty(A) && throw(ArgumentError("at least one mode is required"))
    n = size(first(A), 1)
    for (σ, Aσ) in enumerate(A)
        size(Aσ, 1) == size(Aσ, 2) ||
            throw(ArgumentError("A[$σ] is $(size(Aσ)) and must be square"))
        size(Aσ, 1) == n ||
            throw(ArgumentError("A[$σ] has dimension $(size(Aσ, 1)), expected $n"))
    end
    return mapreduce(eltype, promote_type, A)
end

function _check_inputs(A, B)
    length(A) == length(B) ||
        throw(ArgumentError("A has $(length(A)) modes but B has $(length(B))"))
    n, m = size(first(A), 1), size(first(B), 2)
    for (σ, Bσ) in enumerate(B)
        size(Bσ, 1) == n ||
            throw(ArgumentError("B[$σ] has $(size(Bσ, 1)) rows, expected $n to match A"))
        size(Bσ, 2) == m ||
            throw(ArgumentError("B[$σ] has input dimension $(size(Bσ, 2)), expected $m"))
    end
    return m
end
