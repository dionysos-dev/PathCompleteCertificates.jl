import HybridSystems
import LinearAlgebra
import MathematicalSystems

const _HS = HybridSystems
const _MS = MathematicalSystems

"""
    switched_system(A)
    switched_system(A, B)

The discrete-time switched linear system `x⁺ = A_σ x` or `x⁺ = A_σ x + B_σ u`,
with `A` and `B` indexed by mode, under arbitrary switching.
"""
function switched_system end

function switched_system(A::AbstractVector{<:AbstractMatrix})
    _check_mode_matrices(A)
    return _HS.discreteswitchedsystem(A)
end

function switched_system(
    A::AbstractVector{<:AbstractMatrix},
    B::AbstractVector{<:AbstractMatrix},
)
    n = _check_dimensions(A, B)
    graph = _HS.OneStateAutomaton(length(A))

    # Modes carry no dynamics; the reset maps do, indexed by transition event.
    modes = [_MS.ContinuousIdentitySystem(n) for _ in _HS.states(graph)]
    maps = [_MS.LinearControlMap(A[σ], B[σ]) for σ in eachindex(A)]
    switchings = fill(_HS.AutonomousSwitching(), _HS.nstates(graph))

    return _HS.HybridSystem(graph, modes, maps, switchings)
end

"""
    mode_matrices(system)

The state matrices `A`, indexed by mode.
"""
function mode_matrices(system::_HS.HybridSystem)
    maps = _maps_by_mode(system)

    return [maps[σ].A for σ in 1:length(maps)]
end

"""
    input_matrices(system)

The input matrices `B`, indexed by mode. Throws if the system has no input.
"""
function input_matrices(system::_HS.HybridSystem)
    has_input(system) ||
        throw(ArgumentError("the system has no input, so it has no B matrices"))

    maps = _maps_by_mode(system)

    return [maps[σ].B for σ in 1:length(maps)]
end

"""
    has_input(system) -> Bool

Whether `system` has an input, `x⁺ = A_σ x + B_σ u`.
"""
function has_input(system::_HS.HybridSystem)
    return all(
        hasfield(typeof(_HS.resetmap(system, t)), :B) for
        t in _HS.transitions(system.automaton)
    )
end

"""
    n_modes(system)

The number of modes of `system`. Throws on a system whose automaton restricts
the switching: constrained switching is not supported.
"""
function n_modes(system::_HS.HybridSystem)
    _require_arbitrary_switching(system)
    return _HS.ntransitions(system.automaton)
end

# A system built with HybridSystems may restrict the switching to an automaton.
function _require_arbitrary_switching(system::_HS.HybridSystem)
    system.automaton isa _HS.OneStateAutomaton || throw(
        ArgumentError(
            "constrained switching is not supported: the system's automaton must " *
            "be a `OneStateAutomaton`, which admits every switching sequence",
        ),
    )
    return nothing
end

function _maps_by_mode(system::_HS.HybridSystem)
    maps = Dict{Int, Any}()
    for t in _HS.transitions(system.automaton)
        maps[_HS.event(system.automaton, t)] = _HS.resetmap(system, t)
    end
    return maps
end

# Validate the state matrices, square and of one positive size, and return it.
function _check_mode_matrices(A::AbstractVector{<:AbstractMatrix})
    isempty(A) && throw(ArgumentError("at least one mode is required"))

    n = size(first(A), 1)
    n > 0 || throw(ArgumentError("mode matrices must have positive dimension"))

    for (σ, Aσ) in enumerate(A)
        size(Aσ) == (n, n) ||
            throw(ArgumentError("A[$σ] has size $(size(Aσ)); expected ($n, $n)"))
    end

    return n
end

# Validate the mode and input matrices and return the state dimension.
function _check_dimensions(A, B)
    n = _check_mode_matrices(A)
    length(A) == length(B) ||
        throw(ArgumentError("A has $(length(A)) modes but B has $(length(B))"))

    m = size(first(B), 2)

    for (σ, Bσ) in enumerate(B)
        size(Bσ, 1) == n ||
            throw(ArgumentError("B[$σ] has $(size(Bσ, 1)) rows, expected $n to match A"))
        size(Bσ, 2) == m ||
            throw(ArgumentError("B[$σ] has input dimension $(size(Bσ, 2)), expected $m"))
    end

    return n
end

"""
    mode_matrix(system, mode)
    mode_matrix(system, word)

The state matrix of one mode, or the product ``A_{i_k} ⋯ A_{i_1}`` along a word
`(i_1, …, i_k)`.
"""
mode_matrix(system::_HS.HybridSystem, mode::Integer) = mode_matrices(system)[mode]

mode_matrix(system::_HS.HybridSystem, word::AbstractVector{<:Integer}) =
    _product(mode_matrices(system), word)

# Takes the extracted matrices so that per-edge callers do not rebuild them.
function _product(A::AbstractVector{<:AbstractMatrix}, word)
    isempty(word) && throw(ArgumentError("a word must read at least one mode"))

    product = A[first(word)]

    for mode in Iterators.drop(word, 1)
        product = A[mode] * product
    end

    return product
end

"""
    is_invertible(system) -> Bool

Whether every mode matrix has full rank.
"""
is_invertible(system::_HS.HybridSystem) =
    all(A -> LinearAlgebra.rank(A) == size(A, 1), mode_matrices(system))

"""
    is_positive(system) -> Bool

Whether every mode matrix is entrywise nonnegative.
"""
is_positive(system::_HS.HybridSystem) = all(A -> all(>=(0), A), mode_matrices(system))

"""
    dual(system)

The system with every mode matrix transposed. Throws on a system with input.
"""
function dual(system::_HS.HybridSystem)
    has_input(system) &&
        throw(ArgumentError("the dual of a controlled system is not defined"))
    _require_arbitrary_switching(system)

    return switched_system([collect(transpose(A_mode)) for A_mode in mode_matrices(system)])
end
