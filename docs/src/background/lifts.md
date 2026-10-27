```@meta
CurrentModule = PathCompleteCertificates
```

# Why lifts are valid

## The order between graphs

For a template ``\mathcal V``, ``G \le_{\mathcal V} H`` when every system that
has a certificate on ``G`` with functions in ``\mathcal V`` also has one on
``H`` ([debauche2021comparison](@cite), Def. 4). A lift ``L`` is **valid** for
``\mathcal V`` when ``G \le_{\mathcal V} L(G)`` for every path-complete graph
``G`` (Def. 6). Validity often requires the template to be closed under an
operation, such as addition (Def. 7).

## Lifts that need nothing

**Splits.** Every copy of a node takes the function of the node. Each edge of
the split graph joins copies of the two ends of an edge of the original graph,
with the same mode, so its inequality is one the certificate already satisfies.
Every path of the original graph is read by the split graph, which is therefore
path-complete.

**Products.** An edge reading the word ``w u`` replaces two consecutive edges
reading ``w`` and ``u``. Chaining their two inequalities gives the inequality of
the product edge ([athanasopoulos2019polyhedral](@cite)).

Both are valid for every template, which is why [`refine`](@ref) uses them.

## Lifts that combine node functions

**Simulation.** ``G \le_{\mathcal V} H`` for every template exactly when ``G``
simulates ``H`` ([philippe2019complete](@cite), Def. 3.1 and Thm. 3.5).

**Min and max.** For the templates closed under pointwise minimum,
``G \le_{\mathcal V} H`` exactly when the min lift of ``G`` simulates ``H``
([debauche2024thesis](@cite), Thm. 8.1); the max lift does the same for
maximum (Thm. 8.5). The linear copositive norms are not closed under minimum,
yet the min lift is valid for them on positive systems (Thm. 7.43).

**Sum.** For the templates closed under addition, the order is decided by a
linear program ([debauche2024thesis](@cite), Cor. 8.11).

**Composition.** For the templates closed under composition with the matrices
of a system, a simulation by the composition lift proves the order
([debauche2024thesis](@cite), Def. 7.58 and Thm. 7.65); with the inverse
matrices, by the backward composition lift (Def. 7.61 and Thm. 7.66).
