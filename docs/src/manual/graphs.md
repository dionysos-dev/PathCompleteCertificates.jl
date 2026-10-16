```@meta
CurrentModule = PathCompleteCertificates
```

# Path-complete graphs

A certificate graph is a directed graph with a mode on every edge: nodes
`1:n`, and an edge `(s, d, i)` reading "from node `s`, mode `i` leads to node
`d`". It is a `GraphAutomaton` of HybridSystems.jl. Build one with [`empty_graph`](@ref) and
[`add_edge!`](@ref), and read it with [`nodes`](@ref), [`edges`](@ref),
[`source`](@ref), [`dest`](@ref), [`label`](@ref), [`outgoing_edges`](@ref),
[`incoming_edges`](@ref) and [`alphabet`](@ref).

## Path-completeness

A graph is **path-complete** for an alphabet of modes when every sequence over
it can be read as a path in it ([ahmadi2014joint](@cite), Def. 2.2). A
certificate on a graph proves the property for the sequences the graph reads.
On a path-complete graph these are all of them; on another graph the
certificate covers part of them only. Every problem tests the graph against
the system's modes, `1:`[`n_modes`](@ref)`(system)`, before solving.

```@docs; canonical=false
is_path_complete
```

The test uses the subset construction of automata theory, exponential in the
number of nodes in the worst case, and runs once per solve.
`path_complete = false` on an entry point skips it, for a graph whose
construction guarantees the property, such as a refinement of a path-complete
graph. If the graph is in fact not path-complete, the result is not a
certificate and no error is raised.

!!! warning "Ask about the system's modes"
    `is_path_complete(graph)` alone asks about the modes the graph happens to
    use, so a graph that never mentions a mode passes trivially. Ask
    `is_path_complete(graph, 1:n_modes(system))`, or let the problems do it.

## Complete, co-complete, and the common function

Two stronger properties ([philippe2017path](@cite), Def. III.2): a graph is
**complete** when every node has an outgoing edge for every mode, and
**co-complete** when every node has an incoming edge for every mode. Both
imply path-completeness; neither is necessary. They determine the form of the
**common function**, the single function into which the node functions ``V_s``
of a certificate combine: the minimum over the nodes on a complete graph, the
maximum on a co-complete one (Cor. III.3), and a minimum of maxima over the
observer graph otherwise (Thm. III.8). [`common`](@ref) chooses the form from
the graph. A certificate `c` is callable: `c(x)` evaluates its common function
at `x`.

| Predicate | Meaning |
| :-- | :-- |
| [`is_path_complete`](@ref) | every admissible sequence is readable as a path |
| [`is_complete`](@ref) | every node has an outgoing edge for every mode |
| [`is_co_complete`](@ref) | every node has an incoming edge for every mode |

```@docs; canonical=false
common
```

## The De Bruijn graphs

[`de_bruijn`](@ref)`(k, M)` is the primal De Bruijn graph of order `k` on `M`
modes ([debauche2024thesis](@cite), Def. 6.10): one node per word of `k`
modes, the last `k` modes read, and from every node an edge per mode to the
node that remembers it; `Mᵏ` nodes, and complete. Its [`dual`](@ref) is the
dual De Bruijn graph, co-complete. The two hierarchies are the classical
path-complete graphs ([ahmadi2014joint](@cite)); going one order up is the
in-splitting at every edge, so the certified bound never gets worse
([philippe2016stability](@cite)), with `M` times as many nodes.

[`common_graph`](@ref)`(system)` is order zero, `de_bruijn(0, M)`: the common
Lyapunov function graph ``G_0``, one node with a loop per mode.

```@docs; canonical=false
de_bruijn
common_graph
```

[`refine`](@ref) adds nodes only where the certificate is tight; see [Graph refinement](@ref).

## Words on edges

An edge may read a **word**, a sequence of modes, in a [`WordGraph`](@ref):
one inequality on the product ``A_{i_k} \cdots A_{i_1}`` and nothing on the
states in between. The [`expanded_form`](@ref) reads the same language with
one mode per edge and a fresh node per intermediate step
([ahmadi2014joint](@cite), Def. 2.1), and a word graph is path-complete exactly
when its expanded form is. Words are sound for **stability only**, where an
inequality on a product still bounds the joint spectral radius; safety and
optimal control need every state along the way, and throw on a word graph.
The product refinements produce word graphs.

## The dual graph

[`dual`](@ref)`(graph)` reverses every edge and every word
([debauche2024thesis](@cite), Def. 6.3), and the result is path-complete
exactly when the graph is (Prop. 6.6). [Duality](@ref) is the full account.
