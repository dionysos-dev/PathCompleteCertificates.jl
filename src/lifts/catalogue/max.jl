"""
    MaxLift()

The [`dual`](@ref) of [`MinLift`](@ref): nodes are the nonempty subsets, with
an `i`-edge from `A` to `B` when every node of `B` is reached by an `i`-edge
from `A`. Requires [`Maximum`](@ref); its simulation is the relation on the
dual graphs [debauche2024thesis; Thm. 8.5](@cite).
"""
const MaxLift = DualLift{MinLift}

MaxLift() = DualLift(MinLift())
