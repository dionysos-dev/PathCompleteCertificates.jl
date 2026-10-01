```@meta
CurrentModule = PathCompleteCertificates
```

# Duality

Reverse every edge, transpose every matrix and take the dual norm of every
node function: a certificate becomes a certificate again, at the same rate.
The package carries that involution through every object it has. It is how
every backward construction is obtained from a forward one without code of
its own, and how a declaration made on one template serves its dual.

## What `dual` does to each object

| Object | `dual` of it | Source |
| :-- | :-- | :-- |
| graph | every edge and every word reversed; path-complete exactly when the original is | [debauche2024thesis](@cite), Def. 6.3 and Prop. 6.6 |
| system | every mode matrix transposed; the automaton reversed under constrained switching | [debauche2024thesis](@cite), Lemma 6.25 |
| template | the family of dual norms: quadratic forms are their own, the two copositive templates each other's | [debauche2024thesis](@cite), Def. 1.32 |
| node function | `dual(template, V)`, the dual norm of a fitted function; it satisfies the reversed edge inequality | [debauche2024thesis](@cite), Lemma 1.28 |
| certificate | the dual norms on the dual graph for the dual system, at the same rate, nothing solved | [debauche2024thesis](@cite), Lemmas 6.25 and 6.26 |
| lift | `dual(L)(G) = dual(L(dual(G)))` | [debauche2024thesis](@cite), Def. 7.4 |
| operation | what the dual lift requires: `min` and `max` exchange, `+` is fixed, composition becomes composition with the inverse | [debauche2024thesis](@cite), Lemma 7.45, Prop. 7.13 and Prop. 7.64 |

`dual` is an involution on each: applied twice it gives the object back, down
to the node functions of a certificate. For quadratic forms this is the
classical statement that transposing the matrices and dualising the graph
give the same bound ([ahmadi2014joint](@cite), Thm. 5.1).

## What it buys

- **Every backward lift for free.** [`BackwardEdgeSplit`](@ref),
  [`BackwardEdgeProduct`](@ref), [`MaxLift`](@ref) and the backward
  composition lift are `dual` of their forward counterparts, and the sum and
  product lifts are self-dual. One wrapper, [`DualLift`](@ref), replaces four
  implementations and the transposition bookkeeping that goes wrong by hand.
- **Validity crosses over.** A lift valid for a template has a dual valid for
  the dual template ([debauche2024thesis](@cite), Prop. 7.5).
  [`is_valid`](@ref) therefore reads the dual side when the primal declares
  nothing: the sum lift is valid for the dual copositive norms because the
  primal ones add.
- **Ordering crosses over.** ``G \le_V H`` exactly when
  ``\mathrm{dual}(G) \le_{V^*} \mathrm{dual}(H)`` ([debauche2024thesis](@cite),
  Prop. 6.27), which is why [`order_witness`](@ref) decides the `max`-closed
  case by a relation on the dual graphs.
- **A certificate checked twice.** `dual(certificate)` is a certificate
  without a solve, so the round trip tests the whole construction: the
  reversed inequalities hold by [`edge_slacks`](@ref), a fresh solve on the
  dual problem returns the same rate, and dualising again returns the node
  functions. The test suite runs that on every lift and every template with a
  dual.

Templates without a dual here, the polyhedral and sum-of-squares ones, answer
[`has_dual`](@ref) with `false`, and everything above falls back to the primal
side for them.
