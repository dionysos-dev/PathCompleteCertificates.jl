```@meta
CurrentModule = PathCompleteCertificates
```

# Comparing graphs

```@setup graphs
using PathCompleteCertificates
include(joinpath(pkgdir(PathCompleteCertificates), "docs", "graph_drawing.jl"))

const IMAGE_COLORS = [:palegreen, :lightpink]

function simulation_figure()
    G, H = de_bruijn(1, 2), de_bruijn(2, 2)
    image = simulation(G, H)
    lims = (xlims = (-2.4, 2.4), ylims = (-1.15, 1.15))
    left = draw_graph(G, [(-0.9, 0.0), (0.9, 0.0)]; title = "G, De Bruijn of order 1",
                      node_colors = IMAGE_COLORS, lims...)
    right = draw_graph(H, [(-1.3, 0.0), (0.0, 0.8), (0.0, -0.8), (1.3, 0.0)];
                       title = "H, De Bruijn of order 2, colored by image in G",
                       node_colors = IMAGE_COLORS[image], lims...)
    return plot(left, right; layout = (1, 2), size = (900, 300))
end
```

Parts I and II judge a graph on one system, by solving. Comparing judges two
graphs for every system at once, without computing any certificate. Given a
template ``\mathcal V``,

```math
G \le_{\mathcal V} H
\quad \text{when every system with a certificate on } G
\text{ in } \mathcal V \text{ also has one on } H,
```

so that ``H`` is at least as good as ``G``, whatever the system
[debauche2021comparison; Def. 4](@cite). For stability, scaling the matrices
by ``1/\gamma`` shows that ``H`` then certifies every rate that ``G``
certifies. The order depends on the two graphs and the template only: it
tells, before any system is given, whether a larger graph can pay off, and it
orders the graphs of the literature into hierarchies. Two tools prove it:

- **a simulation**, which proves it for every template.
- **a simulation after a lift**, which proves it for the templates for which
  the lift is valid.

## Simulation

``G`` **simulates** ``H`` when a map ``f`` from the nodes of ``H`` to the
nodes of ``G`` keeps every edge:

```math
(s, d, i) \text{ an edge of } H
\implies (f(s), f(d), i) \text{ an edge of } G.
```

Each node ``s`` of ``H`` then takes the function ``V_{f(s)}`` of its image,
and every edge inequality on ``H`` is one on ``G``: a certificate on ``G``
gives one on ``H``, in any template. Conversely, ``G \le_{\mathcal V} H`` for
every template only when ``G`` simulates ``H``
[philippe2019complete; Thm. 3.5](@cite). [`simulation`](@ref)`(G, H)`
returns ``f``, or `nothing`.

On the De Bruijn hierarchy, order 1 simulates order 2. Each node of ``H`` is
colored as its image in ``G``, and every edge of ``H`` has an edge of ``G``
with the same mode between the same colors:

```@example graphs
simulation_figure() # hide
```

```@example graphs
simulation(de_bruijn(1, 2), de_bruijn(2, 2)),
simulation(de_bruijn(2, 2), de_bruijn(1, 2))
```

Order 2 is therefore at least as good as order 1 for every template. Order 2
does not simulate order 1, so the reverse fails for some template. The
common graph simulates every graph: no graph gives a worse certificate than
a common Lyapunov function.

## Simulation after a lift

Without a simulation, ``H`` may still be at least as good as ``G`` for the
templates for which some lift is valid. Such a lift never makes ``G`` worse
(see [Lifts](@ref)), so when the lifted ``G`` simulates
``H``, ``G \le_{\mathcal V} H`` for every such template:

| Lift | For templates closed under | Decided by |
| :-- | :-- | :-- |
| [`MinLift`](@ref) | minimum | a relation between the nodes, without building the lift |
| [`MaxLift`](@ref) | maximum | the same relation on the dual graphs |
| [`SumLift`](@ref)`()` | addition | a linear program, which needs an `optimizer` |
| [`CompositionLift`](@ref)`(T)`, [`BackwardCompositionLift`](@ref)`(T)` | composition with the matrices of a system, or with their inverses | building the lift and searching it |

For the min, max and sum lifts, the test is also necessary: when the lifted
``G`` does not simulate ``H``, the order fails for some template closed under
the operation. For the composition lifts, a failed search proves nothing. The
rows come from [debauche2024thesis](@citet): Theorems 8.1 and 8.5 for the min
and max lifts, Corollary 8.11 for the sum lift, and Theorems 7.65 and 7.66
for the composition lifts.

[Lifts](@ref) says when a lift is valid for a template, and
[What works with what](@ref) lists the lifts valid for each one.

## Comparing in one call

[`compare`](@ref)`(G, H)` tries the lifts and returns a
[`Comparison`](@ref): [`simulations`](@ref) lists the lifts whose lifted
``G`` simulates ``H``, each with its simulation.

```@example graphs
c = compare(de_bruijn(1, 2), common_graph(2))
simulations(c)
```

The min lift of the De Bruijn graph of order 1 simulates the common graph.
For every template for which the min lift is valid, such as the linear
copositive template on a positive system, this De Bruijn graph therefore gives
no better certificate than the common graph. Given `templates` and a `system`,
[`compare`](@ref) also lists the templates for which the order is proved
(see [Compare two graphs](@ref)).
