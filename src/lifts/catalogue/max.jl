"""
    MaxLift()

The [`dual`](@ref) of [`MinLift`](@ref) [debauche2024thesis; Lemma 7.45](@cite):
nodes are the nonempty subsets, with an `i`-edge from `A` to `B` when every node
of `B` is reached by an `i`-edge from `A`. Requires [`Maximum`](@ref). Its
simulation is the relation on the dual graphs, and decides the order for every
template closed under maximum [debauche2024thesis; Thm. 8.5](@cite).
"""
const MaxLift = DualLift{MinLift}

MaxLift() = DualLift(MinLift())
