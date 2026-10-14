"""
    switched_system(A)
    switched_system(A, B)

The discrete-time switched linear system `x⁺ = A_σ x` or `x⁺ = A_σ x + B_σ u`,
with `A` and `B` indexed by mode, under arbitrary switching.
"""
function switched_system end

function switched_system(A::AbstractVector{<:AbstractMatrix})
    _check_state_matrices(A)
    return _HS.discreteswitchedsystem(A)
end

# HybridSystems has no constructor for a controlled switched system, so this one
# assembles the system that `discreteswitchedsystem` would.
function switched_system(
    A::AbstractVector{<:AbstractMatrix},
    B::AbstractVector{<:AbstractMatrix},
)
    n = _check_input_matrices(A, B)
    graph = _HS.OneStateAutomaton(length(A))

    # Modes carry no dynamics; the reset maps do, indexed by transition event.
    modes = [_MS.ContinuousIdentitySystem(n) for _ in _HS.states(graph)]
    # One element type per mode, which `LinearControlMap` requires of `A` and `B`.
    maps = [_MS.LinearControlMap(promote(A[σ], B[σ])...) for σ in eachindex(A)]
    switchings = fill(_HS.AutonomousSwitching(), _HS.nstates(graph))

    return _HS.HybridSystem(graph, modes, maps, switchings)
end

# Validate the state matrices, square and of one positive size, and return their
# size.
function _check_state_matrices(A::AbstractVector{<:AbstractMatrix})
    isempty(A) && throw(ArgumentError("at least one mode is required"))

    n = size(first(A), 1)
    n > 0 || throw(ArgumentError("mode matrices must have positive dimension"))

    for (σ, Aσ) in enumerate(A)
        size(Aσ) == (n, n) ||
            throw(ArgumentError("A[$σ] has size $(size(Aσ)); expected ($n, $n)"))
    end

    return n
end

# Validate the state and input matrices, one input size for every mode, and
# return the state dimension.
function _check_input_matrices(A, B)
    n = _check_state_matrices(A)
    length(A) == length(B) ||
        throw(ArgumentError("A has $(length(A)) modes but B has $(length(B))"))

    m = size(first(B), 2)
    m > 0 || throw(ArgumentError("input matrices must have at least one column"))

    for (σ, Bσ) in enumerate(B)
        size(Bσ, 1) == n ||
            throw(ArgumentError("B[$σ] has $(size(Bσ, 1)) rows, expected $n to match A"))
        size(Bσ, 2) == m ||
            throw(ArgumentError("B[$σ] has input dimension $(size(Bσ, 2)), expected $m"))
    end

    return n
end

"""
    state_matrices(system)

The state matrices `A`, indexed by mode.
"""
state_matrices(system::_HS.HybridSystem) = _MS.state_matrix.(_maps_by_mode(system))

"""
    state_matrix(system, word)

The product ``A_{i_k} ⋯ A_{i_1}`` of the state matrices along a word
`(i_1, …, i_k)`.
"""
state_matrix(system::_HS.HybridSystem, word::AbstractVector{<:Integer}) =
    _product(state_matrices(system), word)

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
    input_matrices(system)

The input matrices `B`, indexed by mode. Throws if the system has no input.
"""
function input_matrices(system::_HS.HybridSystem)
    has_input(system) ||
        throw(ArgumentError("the system has no input, so it has no B matrices"))

    return _MS.input_matrix.(_maps_by_mode(system))
end

"""
    has_input(system) -> Bool

Whether `system` has an input, `x⁺ = A_σ x + B_σ u`.
"""
has_input(system::_HS.HybridSystem) =
    all(map -> map isa _MS.LinearControlMap, _maps_by_mode(system))

"""
    n_modes(system)

The number of modes of `system`. Throws on a system whose automaton restricts
the switching: constrained switching is not supported.
"""
n_modes(system::_HS.HybridSystem) = length(_maps_by_mode(system))

# The reset map `x ↦ A_σ x (+ B_σ u)` of each mode σ, in mode order. Every
# accessor goes through here, so this is where constrained switching, which
# HybridSystems allows, is rejected. A `OneStateAutomaton` has one transition per
# mode.
function _maps_by_mode(system::_HS.HybridSystem)
    automaton = system.automaton
    automaton isa _HS.OneStateAutomaton || throw(
        ArgumentError(
            "constrained switching is not supported: the system's automaton must " *
            "be a `OneStateAutomaton`, which admits every switching sequence",
        ),
    )

    return [_HS.resetmap(system, t) for t in _HS.transitions(automaton)]
end

# Whether every mode matrix has full rank: what the composition lifts need of the
# quadratic, sum-of-squares and linear copositive templates.
_is_invertible(system::_HS.HybridSystem) =
    all(A -> LinearAlgebra.rank(A) == size(A, 1), state_matrices(system))

# Whether every mode matrix is entrywise nonnegative, a positive system: what
# the copositive templates need to apply.
_is_positive(system::_HS.HybridSystem) = all(A -> all(>=(0), A), state_matrices(system))

"""
    dual(system)

The system with every mode matrix transposed. Throws on a system with input.
"""
function dual(system::_HS.HybridSystem)
    has_input(system) &&
        throw(ArgumentError("the dual of a controlled system is not defined"))

    return switched_system(permutedims.(state_matrices(system)))
end
