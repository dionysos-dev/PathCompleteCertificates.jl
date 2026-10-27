```@meta
CurrentModule = PathCompleteCertificates
```

# Comparing graphs

## The question

Given two path-complete graphs ``G`` and ``H`` and a template
``\mathcal V``, does ``H`` give a bound at least as good as ``G`` for every
system? When it does, we write ``G \le_{\mathcal V} H``. The answer depends on
the graphs and on the template, not on a particular system.

## Simulation

``G`` **simulates** ``H`` when each node of ``H`` can be mapped to a node of
``G`` so that every edge of ``H`` becomes an edge of ``G`` with the same mode.
A certificate on ``G`` then gives one on ``H``, in any template, so
``G \le_{\mathcal V} H`` for every ``\mathcal V``. [`simulation`](@ref)`(G, H)`
returns the map, or `nothing`:

```@example
import PathCompleteCertificates as PCC
PCC.simulation(PCC.common_graph(2), PCC.de_bruijn(2, 2))
```

The one-node graph simulates every graph: no graph gives a worse bound than a
common Lyapunov function.

## Template-dependent lifts

Without a simulation, ``H`` may still be at least as good for the templates
closed under some operation. The lift of that operation transforms ``G``, and
when the lifted ``G`` simulates ``H``, ``G \le_{\mathcal V} H`` for every such
template.

### Min and max lifts

For templates closed under pointwise minimum, or maximum. Each is decided by a
relation between the nodes, without building the lifted graph, and a missing
simulation means that the order fails for some template closed under the
operation.

### Sum lift

For templates closed under addition. `SumLift()` is decided by a linear
program, and needs an `optimizer`.

### Composition lifts

For templates closed under composition with the matrices of a given system, or
with their inverses. The lifted graph is built and searched. A missing
simulation proves nothing.

### Closure properties of the templates

[`is_closed_under`](@ref) returns the closures of a template, and
[`is_valid`](@ref) whether a lift is valid for a template on a system:

| Template | addition | maximum | minimum | composition |
| :-- | :-: | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref) | ✓ | | | if the matrices are invertible |
| [`SumOfSquaresTemplate`](@ref) | ✓ | | | if the matrices are invertible |
| [`LinearCopositiveTemplate`](@ref) | ✓ | | the min lift is valid ¹ | if the matrices are nonnegative with no zero column |
| [`DualCopositiveTemplate`](@ref) | | ✓ | | |
| [`ParallelFacesPolyhedralTemplate`](@ref) | | if every node has the same faces | | |
| [`ConicPolyhedralTemplate`](@ref) | | | | |
| piecewise SetProg ellipsoid or polytope | if every node has the same partition | | | |

¹ The linear copositive template is not closed under minimum, but the min lift
is valid for it on positive systems, through its dual template; see
[Duality](@ref).

## Comparing in one call

[`compare`](@ref)`(G, H)` tries the lifts and returns those whose lifted ``G``
simulates ``H``:

```@example
import PathCompleteCertificates as PCC
c = PCC.compare(PCC.de_bruijn(1, 2), PCC.common_graph(2))
PCC.simulations(c)
```

The min lift of the De Bruijn graph simulates the one-node graph. For the
templates the min lift is valid for, such as the linear copositive template on
a positive system, this De Bruijn graph gives no better bound than a common
Lyapunov function. Given `templates` and a `system`, [`compare`](@ref) also
lists the templates for which the order is proved; see
[Compare two graphs](@ref).
