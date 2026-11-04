```@meta
CurrentModule = PathCompleteCertificates
```

# Duality

```@setup running
using PathCompleteCertificates
import Clarabel
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = switched_system(A)
problem = StabilityProblem(system)
```

Graphs, systems, lifts, and some templates and certificates have a dual:
reverse the edges of a graph, transpose the matrices of a system, replace
each node function by its dual. [`dual`](@ref) computes it, and applying it
twice gives the object back. It is a tool on the framework itself: each graph
and lift, and each stability certificate whose template has a dual, gets a
counterpart at no cost.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, and
`problem = StabilityProblem(system)`, solved with Clarabel.

## The dual of each object

The numbers in parentheses refer to [debauche2024thesis](@citet).

| `dual` of | gives |
| :-- | :-- |
| a graph | the same nodes with every edge reversed, path-complete exactly when the graph is (Prop. 6.6) |
| a system | the same modes with every matrix transposed |
| a stability problem | the stability problem of the dual system |
| a template | the template of the dual functions, when [`has_dual`](@ref) holds |
| a stability certificate | the dual functions on the dual graph, for the dual system, at the same rate |
| a lift ``L`` | the lift that applies ``L`` to the dual graph and reverses the result: ``\operatorname{dual}(L)(G) = \operatorname{dual}(L(\operatorname{dual}(G)))`` |

Quadratic forms are their own duals. The linear copositive and dual copositive
templates are each other's, and so are the piecewise linear and dual
piecewise linear templates, on the same partition (see
[Choosing a template](@ref)). The other templates have no dual here.

**Why a dual certificate is a certificate.** For a template of norms, node
functions form a certificate on a graph for a system exactly when their dual
norms form one on the dual graph for the transposed system (Lemma 6.25).

## What you gain

**A second certificate, without solving.** On the running example:

```@example running
c = certify(QuadraticTemplate(), common_graph(system), problem; optimizer = Clarabel.Optimizer)
d = dual(c)
c.rate == d.rate
```

**A second hierarchy of graphs.** The dual De Bruijn graphs,
`dual(de_bruijn(k, M))`, read the next modes where the De Bruijn graphs read
the last (see [Choosing a graph](@ref)). Refinement meets them (see
[Refining the graph](@ref)).

**The backward lifts.** [`InSplitLift`](@ref), [`BackwardProductLift`](@ref),
[`MaxLift`](@ref) and [`BackwardCompositionLift`](@ref) are the duals of
[`OutSplitLift`](@ref), [`ForwardProductLift`](@ref), [`MinLift`](@ref) and
[`CompositionLift`](@ref).

**Comparisons through the dual.** With ``\mathcal V^*`` the template of the
dual norms:

- ``G \le_{\mathcal V} H`` exactly when
  ``\operatorname{dual}(G) \le_{\mathcal V^*} \operatorname{dual}(H)``
  (Prop. 6.27).
- A lift is valid for a template exactly when its dual lift is valid for the
  dual template (Prop. 7.5), so a lift can be valid for a template that is
  not closed under its operation (see [Lifts](@ref)).
- The max lift is the dual of the min lift (Lemma 7.45), and is decided by
  the relation of the min lift on the dual graphs (see
  [Comparing graphs](@ref)).
