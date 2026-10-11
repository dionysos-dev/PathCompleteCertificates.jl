"""
    MaxLift()

Nodes are the nonempty subsets; `(A, B, i)` is an edge when every node of `B`
is reached by an `i`-edge from `A` (Debauche, Della Rossa & Jungers, Def. 9).
The dual of [`MinLift`](@ref) (Debauche, Lemma 7.45), valid for templates
closed under [`Maximum`](@ref); its simulation is the relation on the dual
graphs, complete for them (Debauche, Thm. 8.5).
"""
const MaxLift = DualLift{MinLift}

MaxLift() = DualLift(MinLift())
