"""
Interop with `HybridSystems.jl`, loaded only when the user has it.

A switched system encoded as a `HybridSystem` is one discrete state whose modes
carry no dynamics, with the matrices on self-loop transitions keyed by event.
"""
module PathCompleteCertificatesHybridSystemsExt

import PathCompleteCertificates as PCC
import HybridSystems as HS
import MathematicalSystems as MS

# --- ours -> theirs -------------------------------------------------------

"""
    HybridSystem(system)

Encode a switched system as a `HybridSystems.HybridSystem`, so that tools built
on that vocabulary accept it.
"""
function HS.HybridSystem(system::PCC.AbstractSwitchedSystem)
    automaton = _automaton(system)
    modes = [MS.ContinuousIdentitySystem(MS.statedim(system)) for _ in HS.states(automaton)]
    return HS.HybridSystem(
        automaton,
        modes,
        _resetmaps(system),
        fill(HS.AutonomousSwitching(), HS.nstates(automaton)),
    )
end

_resetmaps(system::PCC.SwitchedLinearSystem) =
    [MS.LinearMap(MS.state_matrix(system, σ)) for σ in PCC.modes(system)]

_resetmaps(system::PCC.SwitchedLinearControlSystem) = [
    MS.LinearControlMap(MS.state_matrix(system, σ), MS.input_matrix(system, σ)) for
    σ in PCC.modes(system)
]

# Arbitrary switching is one state with a self-loop per mode.
function _automaton(system::PCC.AbstractSwitchedSystem)
    c = PCC.constraint(system)
    c === nothing && return HS.OneStateAutomaton(PCC.nmodes(system))
    return c
end

# --- theirs -> ours -------------------------------------------------------

"""
    SwitchedLinearSystem(hs)
    SwitchedLinearControlSystem(hs)

Read a switched system back out of a `HybridSystem`.

Throws if `hs` is not one: a genuine hybrid automaton has per-mode dynamics,
guards and resets, none of which survive the conversion.
"""
function PCC.SwitchedLinearSystem(hs::HS.HybridSystem)
    maps = _maps_by_mode(hs)
    all(m isa MS.LinearMap for m in maps) || throw(
        ArgumentError(
            "reset maps are not plain LinearMaps; use SwitchedLinearControlSystem",
        ),
    )
    return PCC.SwitchedLinearSystem([m.A for m in maps]; constraint = _constraint(hs))
end

function PCC.SwitchedLinearControlSystem(hs::HS.HybridSystem)
    maps = _maps_by_mode(hs)
    all(m isa MS.LinearControlMap for m in maps) ||
        throw(ArgumentError("reset maps do not carry an input matrix"))
    return PCC.SwitchedLinearControlSystem(
        [m.A for m in maps],
        [m.B for m in maps];
        constraint = _constraint(hs),
    )
end

_constraint(hs::HS.HybridSystem) =
    hs.automaton isa HS.OneStateAutomaton ? nothing : hs.automaton

"Reset maps in mode order. They are stored keyed by the transition's event."
function _maps_by_mode(hs::HS.HybridSystem)
    by_event = Dict{Int, Any}()
    for t in HS.transitions(hs.automaton)
        by_event[HS.event(hs.automaton, t)] = HS.resetmap(hs, t)
    end
    return [by_event[σ] for σ in 1:length(by_event)]
end

end
