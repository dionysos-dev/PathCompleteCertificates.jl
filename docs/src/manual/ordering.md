```@meta
CurrentModule = PathCompleteCertificates
```

# Comparing graphs

Given two path-complete graphs, is one **guaranteed no worse** than the other —
does every system certified on the first get certified on the second, with the
same template? That is the ordering of [debauche2021comparison](@cite), Def. 4,
and the answer depends on what the template is closed under. The package
decides it with three procedures, each a relaxation of graph homomorphism and
each complete for the closure it serves.
[Comparing graphs: which one is better?](@ref) runs all three on the five
graphs of [debauche2023ordering](@cite) and confirms every verdict with rates.

| Templates | Procedure | Witness | Cost |
| :-- | :-- | :-- | :-- |
| all | [`simulation`](@ref): a **map** from the nodes of `H` to those of `G` preserving labelled edges | the map | NP-hard, small in practice |
| closed under `min` | [`simulation_relation`](@ref): the greatest **relation** in which every move of `H` is matched by a move of `G` | the relation | polynomial |
| closed under `max` | the same on the dual graphs | the relation | polynomial |
| closed under `+` | [`conic_witness`](@ref): a nonnegative **matrix** `C` writing certificates of `H` as combinations of certificates of `G` | an integer matrix | a linear program |

[`order_witness`](@ref) reads the template's closures and runs what they
entitle it to; [`is_no_worse`](@ref) is its Boolean. The witness comes back
because it is what you check by hand: a map, a relation, or a matrix with every
row summing to at least one.

The relation is exactly the question *does the [`MinLift`](@ref) of `G`
simulate `H`?* read off the relation rather than the exponential lift
(Debauche, Thm. 8.1); the matrix is exactly *does some [`SumLift`](@ref) of `G`
simulate `H`?* decided by the linear program of
[philippe2017path](@cite), Thm. IV.4 (Debauche, Thm. 7.35). Neither subset lift
is built to decide anything.

## When a graph buys nothing

For a template closed under `min`, a graph with a nonempty **complete induced
subgraph** — every node of it has, for every mode, an edge reading that mode
into the subgraph — certifies nothing a one-node graph would not: the minimum
of the node functions over the subgraph is a common function. Dually for `max`
and a co-complete induced subgraph. [`closed_subgraph`](@ref) finds the largest
one as a fixed point, and [`simplify`](@ref) returns the one-node graph when it
applies.

Measured: with the fixed-facet polyhedral template, which is `max`-closed, every
co-complete De Bruijn graph certifies exactly the one-node rate, at any order,
while the complete orientation improves; and on the positive system of
Debauche, Della Rossa & Jungers (HSCC 2023) the copositive template gives the
one-node rate on the two graphs with a complete induced subgraph and strictly
better rates on the two without.

## The template-free order

A map — [`simulation`](@ref) — decides the order that holds for every template
and every system ([philippe2017path](@cite); Philippe & Jungers, HSCC 2019). It
is a labelled graph homomorphism, NP-hard in general, searched by backtracking
inside the relation above, which is a necessary condition for it.
