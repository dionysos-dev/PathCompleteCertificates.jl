```@meta
CurrentModule = PathCompleteCertificates
```

# Duality

Reversing every edge of the graph, transposing every mode matrix and replacing
every node function by its dual norm turns a certificate into a certificate at
the same rate. [`dual`](@ref) applies this operation to each object of the
package, and every backward construction is the dual of a forward one.

## What `dual` does to each object

| Object | `dual` of it | Source |
| :-- | :-- | :-- |
| graph | every edge and every word reversed; path-complete exactly when the original is | [debauche2024thesis](@cite), Def. 6.3 and Prop. 6.6 |
| system | every mode matrix transposed | [debauche2024thesis](@cite), Lemma 6.25 |
| template | the family of dual norms: quadratic forms are their own, the two copositive templates each other's | [debauche2024thesis](@cite), Def. 1.32 |
| node function | `dual(template, V)`, the dual norm of a fitted function; it satisfies the reversed edge inequality | [debauche2024thesis](@cite), Lemma 1.28 |
| certificate | the dual norms on the dual graph for the dual system, at the same rate, nothing solved | [debauche2024thesis](@cite), Lemmas 6.25 and 6.26 |
| lift | `dual(L)(G) = dual(L(dual(G)))`; a lift's simulation becomes the same on the dual graphs | [debauche2024thesis](@cite), Def. 7.4 |
| operation | what the dual lift requires: `min` and `max` exchange, `+` is fixed, composition becomes composition with the inverse | [debauche2024thesis](@cite), Lemma 7.45, Prop. 7.13 and Prop. 7.64 |

`dual` is an involution on each: applied twice it gives the object back, down
to the node functions of a certificate. For quadratic forms this is the
classical statement that transposing the matrices and dualising the graph
give the same bound ([ahmadi2014joint](@cite), Thm. 5.1).

## Consequences

- **Backward lifts.** [`InSplitLift`](@ref),
  [`BackwardProductLift`](@ref), [`MaxLift`](@ref) and
  [`BackwardCompositionLift`](@ref) are `dual` of their forward counterparts,
  and [`SumLift`](@ref) and [`ProductLift`](@ref) are their own duals.
- **Validity of lifts.** A lift valid for a template has a dual valid for the
  dual template ([debauche2024thesis](@cite), Prop. 7.5), so
  [`is_valid`](@ref) also reads the closures of the dual template: the sum lift
  is valid for the dual copositive template because the linear copositive
  template is closed under addition.
- **Order.** ``G \le_V H`` exactly when
  ``\mathrm{dual}(G) \le_{V^*} \mathrm{dual}(H)`` ([debauche2024thesis](@cite),
  Prop. 6.27), and [`MaxLift`](@ref) decides the `max`-closed case by a
  relation on the dual graphs.
- **A check of a certificate.** `dual(certificate)` is computed without a
  solve. Its reversed edge inequalities hold by [`edge_slacks`](@ref), a solve
  of the dual problem returns the same rate, and applying `dual` again returns
  the node functions.

Templates without a dual here, the polyhedral and sum-of-squares ones, answer
[`has_dual`](@ref) with `false`, and [`is_valid`](@ref) reads only their own
closures.
