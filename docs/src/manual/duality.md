```@meta
CurrentModule = PathCompleteCertificates
```

# Duality

```@setup running
import PathCompleteCertificates as PCC
import Clarabel
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)
```

Reversing every edge of a graph, transposing every matrix and replacing every
node function by its dual turns a stability certificate into another
certificate, at the same rate. [`dual`](@ref) does this for each object of the
package; why it works is in [Why duality holds](@ref).

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = PCC.StabilityProblem(system)`, solved with Clarabel.

## The dual of each object

| `dual` of | gives |
| :-- | :-- |
| a graph | the same graph with every edge reversed, path-complete exactly when the graph is |
| a system | the same system with every matrix transposed |
| a template | the template of the dual functions, when [`has_dual`](@ref) holds |
| a certificate | the dual functions on the dual graph, for the dual system, at the same rate |
| a lift | the same lift applied on the dual graph |

Applying `dual` twice gives the object back.

## What you gain

**A second certificate, without solving.** For stability:

```@example running
c = PCC.certify(PCC.QuadraticTemplate(), PCC.common_graph(system), problem; optimizer = Clarabel.Optimizer)
d = PCC.dual(c)
c.rate == d.rate
```

**A second hierarchy of graphs.** The dual De Bruijn graphs,
`dual(de_bruijn(k, M))`; see [Choosing a graph](@ref).

**The backward lifts.** [`InSplitLift`](@ref), [`BackwardProductLift`](@ref),
[`MaxLift`](@ref) and [`BackwardCompositionLift`](@ref) are the duals of
[`OutSplitLift`](@ref), [`ForwardProductLift`](@ref), [`MinLift`](@ref) and
[`CompositionLift`](@ref).

Quadratic forms are their own duals, and the two copositive templates are each
other's. The other templates have no dual here.
