import HybridSystems
import MathematicalSystems

const _HS = HybridSystems
const _MS = MathematicalSystems

"""
    SwitchedLinearControlSystem

`x⁺ = A_σ x + B_σ u`, constrained or not.

An alias for the `HybridSystem` parametrisation [`switched_system`](@ref)
returns with an input, so a method can dispatch on it without spelling out four
type parameters. The automaton is left open, so a system whose switching is
restricted still matches.

This is a test of *shape*, not of a property: it says the system has the
parametrisation of a switched linear control system. To ask whether a system has
an input at all — including one assembled by hand, which need not match this
parametrisation — use [`has_input`](@ref), which reads the reset maps. The
problem constructors guard with `has_input` for exactly that reason; the alias
pins what `switched_system` *returns*, so a later change emitting an affine or
constrained map cannot pass unnoticed.
"""
const SwitchedLinearControlSystem = _HS.HybridSystem{
    <:_HS.AbstractAutomaton,
    <:_MS.ContinuousIdentitySystem,
    <:_MS.LinearControlMap,
    _HS.AutonomousSwitching,
}

"""
    switched_system(A; automaton = nothing)
    switched_system(A, B; automaton = nothing)

A discrete-time switched linear system, `x⁺ = A_σ x` or `x⁺ = A_σ x + B_σ u`,
as a `HybridSystems.HybridSystem`.

`A` and `B` are indexed by mode. `automaton` restricts which switching sequences
are admissible; the default admits every sequence.

Switching is autonomous — the *mode* is not ours to choose, the *input* is.

The matrices sit on the transitions, keyed by mode, and the modes themselves
carry no dynamics — use [`mode_matrices`](@ref) rather than `system.modes`.

```julia
A = [[1.0 0.0; 0.0 0.5], [0.5 0.0; 0.0 1.0]]
B = [reshape([1.0, 0.0], 2, 1), reshape([0.0, 1.0], 2, 1)]
switched_system(A, B)
```
"""
function switched_system end

function switched_system(A::AbstractVector{<:AbstractMatrix}; automaton = nothing)
    return automaton === nothing ? _HS.discreteswitchedsystem(A) :
           _HS.discreteswitchedsystem(A, automaton)
end

function switched_system(
    A::AbstractVector{<:AbstractMatrix},
    B::AbstractVector{<:AbstractMatrix};
    automaton = nothing,
)
    n = _check_dimensions(A, B)
    graph = automaton === nothing ? _HS.OneStateAutomaton(length(A)) : automaton

    # Modes carry no dynamics; the reset maps do, indexed by transition event.
    modes = [_MS.ContinuousIdentitySystem(n) for _ in _HS.states(graph)]
    maps = [_MS.LinearControlMap(A[σ], B[σ]) for σ in eachindex(A)]
    switchings = fill(_HS.AutonomousSwitching(), _HS.nstates(graph))

    return _HS.HybridSystem(graph, modes, maps, switchings)
end

"""
    mode_matrices(system)

The state matrices `A`, indexed by mode.

Needed because the matrices live on the transitions, keyed by event — reading
`system.resetmaps` works only while those happen to be ordered by label.

For a system with an input this returns `A` alone; use [`input_matrices`](@ref)
for `B`. It used to return `A` or the pair `(A, B)` depending on a runtime
check, which made it type-unstable and — worse — let `A, B = mode_matrices(sys)`
silently destructure a two-mode input-free system into two matrices and report a
nonsense state dimension.
"""
function mode_matrices(system::_HS.HybridSystem)
    maps = _maps_by_mode(system)

    return [maps[σ].A for σ in 1:length(maps)]
end

"""
    input_matrices(system)

The input matrices `B`, indexed by mode.

Throws if the system has no input, rather than returning something empty: a
caller asking for `B` on an autonomous system has made a mistake worth hearing
about.
"""
function input_matrices(system::_HS.HybridSystem)
    has_input(system) ||
        throw(ArgumentError("the system has no input, so it has no B matrices"))

    maps = _maps_by_mode(system)

    return [maps[σ].B for σ in 1:length(maps)]
end

"""
    has_input(system) -> Bool

Whether the reset maps of `system` carry a control input.

`MathematicalSystems.iscontrolled` asks the same question, but extending it for
`HybridSystem` would be type piracy — their function on their type — so this one
is ours.
"""
function has_input(system::_HS.HybridSystem)
    return all(
        hasfield(typeof(_HS.resetmap(system, t)), :B) for
        t in _HS.transitions(system.automaton)
    )
end

"Reset maps keyed by mode, i.e. by the transition's event."
function _maps_by_mode(system::_HS.HybridSystem)
    maps = Dict{Int, Any}()
    for t in _HS.transitions(system.automaton)
        maps[_HS.event(system.automaton, t)] = _HS.resetmap(system, t)
    end
    return maps
end

"Validate the mode data and return the shared state dimension."
function _check_dimensions(A, B)
    isempty(A) && throw(ArgumentError("at least one mode is required"))
    length(A) == length(B) ||
        throw(ArgumentError("A has $(length(A)) modes but B has $(length(B))"))

    n = size(first(A), 1)
    m = size(first(B), 2)

    for (σ, Aσ) in enumerate(A)
        size(Aσ, 1) == size(Aσ, 2) ||
            throw(ArgumentError("A[$σ] is $(size(Aσ)) and must be square"))
        size(Aσ, 1) == n ||
            throw(ArgumentError("A[$σ] has state dimension $(size(Aσ, 1)), expected $n"))
    end
    for (σ, Bσ) in enumerate(B)
        size(Bσ, 1) == n ||
            throw(ArgumentError("B[$σ] has $(size(Bσ, 1)) rows, expected $n to match A"))
        size(Bσ, 2) == m ||
            throw(ArgumentError("B[$σ] has input dimension $(size(Bσ, 2)), expected $m"))
    end

    return n
end
