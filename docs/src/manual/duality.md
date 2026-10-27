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

Graphs, systems, lifts, and some templates and certificates have a dual:
reverse the edges of a graph, transpose the matrices of a system, replace
each node function by its dual. [`dual`](@ref) computes it, and applying it
twice gives the object back. For stability, duality turns a certificate into
another one, on the reversed graph, for the transposed system, at the same
rate. It is a tool on the framework itself: each graph, lift and certificate
gets a counterpart at no cost. Why it works is in [Why duality holds](@ref).

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = PCC.StabilityProblem(system)`, solved with Clarabel.

## The dual of each object

| `dual` of | gives |
| :-- | :-- |
| a graph | the same nodes with every edge reversed, path-complete exactly when the graph is |
| a system | the same modes with every matrix transposed |
| a stability problem | the stability problem of the dual system |
| a template | the template of the dual functions, when [`has_dual`](@ref) holds |
| a stability certificate | the dual functions on the dual graph, for the dual system, at the same rate |
| a lift ``L`` | the lift that applies ``L`` to the dual graph and reverses the result: ``\operatorname{dual}(L)(G) = \operatorname{dual}(L(\operatorname{dual}(G)))`` |

Quadratic forms are their own duals, and the linear copositive and dual
copositive templates are each other's. The other templates have no dual here.

## What you gain

**A second certificate, without solving.** On the running example:

```@example running
c = PCC.certify(PCC.QuadraticTemplate(), PCC.common_graph(system), problem; optimizer = Clarabel.Optimizer)
d = PCC.dual(c)
c.rate == d.rate
```

**A second hierarchy of graphs.** The dual De Bruijn graphs,
`dual(de_bruijn(k, M))`, read the next modes where the primal ones read the
last; see [Choosing a graph](@ref). Refinement meets them: its first step
from the one-node graph gives the dual De Bruijn graph of order 1.

**The backward lifts.** [`InSplitLift`](@ref), [`BackwardProductLift`](@ref),
[`MaxLift`](@ref) and [`BackwardCompositionLift`](@ref) are the duals of
[`OutSplitLift`](@ref), [`ForwardProductLift`](@ref), [`MinLift`](@ref) and
[`CompositionLift`](@ref).

**Comparisons through the dual.** A lift is valid for a template when the
dual template is closed under the dual operation: on positive systems, the
min lift is valid for the linear copositive template because the dual
copositive template is closed under maximum. The max lift is decided by the
relation of the min lift on the dual graphs. See [Lifts](@ref) and
[Comparing graphs](@ref).
