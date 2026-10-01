```@meta
CurrentModule = PathCompleteCertificates
```

# Path-complete graphs

The graph is the object of study here, not an internal device. This page is
what a certificate graph is, when it is sound, how to build one and what can
be read off it. [Lifts](@ref), [Comparing graphs](@ref) and
[Refinement: designing the graph](@ref) are what to do with one.

## What a certificate graph is

A directed graph with a mode on every edge: nodes `1:n`, and an edge
`(s, d, i)` reading "from node `s`, mode `i` leads to node `d`". It is a
`GraphAutomaton` of HybridSystems.jl, the same type a constrained system uses
for its switching automaton, so one vocabulary serves both. Build one with
[`empty_graph`](@ref) and [`add_edge!`](@ref), or with HybridSystems'
`add_transition!`; read it with [`nodes`](@ref), [`edges`](@ref),
[`source`](@ref), [`dest`](@ref), [`label`](@ref), [`outgoing_edges`](@ref),
[`incoming_edges`](@ref), [`alphabet`](@ref) and the rest of the
[Graph reference](@ref).

An edge may also read a **word**, a sequence of modes, in a
[`WordGraph`](@ref); see [Words on edges](@ref) below.

## The soundness condition

A graph is **path-complete** for an alphabet when every finite sequence of
modes is readable as a path ([philippe2017path](@cite), Def. II.1). The edge
inequalities of a certificate are local. Path-completeness is what makes them
say something about every switching sequence, and without it they certify
nothing. Every entry point checks it.

```@docs; canonical=false
is_path_complete
```

!!! danger "Path-completeness is relative to an alphabet"
    `is_path_complete(graph)` asks only about the labels the graph happens to
    use, so a graph that never mentions a mode passes trivially and certifies
    nothing about that mode. That once returned a bound of `0.906` for a
    system whose joint spectral radius is at least `3`. Pass the system's
    alphabet, `is_path_complete(graph, 1:n_modes)`, or its automaton under
    constrained switching. Every problem does this for you.

Under **constrained switching** the sequences to read are the paths of the
system's automaton rather than every word ([philippe2016stability](@cite)).
`is_path_complete(graph, automaton)` decides that, and [`language`](@ref)
returns the right object for a system either way.

Deciding path-completeness is PSPACE-complete in general, by the subset
construction. On De Bruijn graphs it is cheap, and a complete or co-complete
graph settles it without the construction. `path_complete = false` on any
entry point skips the check.

!!! warning "`path_complete = false` is an assertion, not a question"
    Assert it wrongly and you get a certificate that certifies nothing, with no
    error and no warning. It is for a graph whose construction guarantees the
    property, such as a lift of a path-complete graph, which is how
    [`refine`](@ref) uses it after its first step.

## Three predicates

| Predicate | Source | Meaning |
| :-- | :-- | :-- |
| [`is_path_complete`](@ref) | [philippe2017path](@cite), Def. II.1 | **every** switching sequence is readable as a path |
| [`is_complete`](@ref) | [philippe2017path](@cite), Def. III.2 | every node has an *outgoing* edge for every mode |
| [`is_co_complete`](@ref) | [philippe2017path](@cite), Def. III.2 | every node has an *incoming* edge for every mode |

The last two are **sufficient, not necessary**: a graph can read every word
without every node reading every letter. "Is this a valid certificate?" is
always [`is_path_complete`](@ref). None of the three is graph-theoretic
completeness. What the sufficient conditions buy is a cheaper check and a
simpler aggregation.

## From node functions to one function

A certificate gives one function per node. [`common`](@ref) combines them into
the single function that certifies the system: the minimum over the nodes of a
complete graph, the maximum for a co-complete one
([philippe2017path](@cite), Cor. III.3), and a minimum of maxima over the
[`observer_graph`](@ref) in general (Thm. III.8). It picks for you, and
`certificate(x)` evaluates it.

```@docs; canonical=false
common
```

## Building one

[`de_bruijn`](@ref)`(k, m)` remembers the last `k` modes at `mᵏ` nodes, in the
complete orientation or the co-complete one. [`seed`](@ref)`(system)` is the
smallest graph that reads a system's language: one node with a loop per mode
under arbitrary switching, the system's own automaton otherwise. It is where
[`refine`](@ref) starts. Any graph built by hand works once it passes the
check.

```@docs; canonical=false
de_bruijn
seed
```

A higher De Bruijn order buys a tighter bound at exponential cost, and spends
its nodes on remembering the last `k` modes whether or not that is where the
certificate is tight. The alternatives are the three pages that follow:
[Lifts](@ref) transform a graph, [Comparing graphs](@ref) orders two, and
[Refinement: designing the graph](@ref) grows one from its certificate.

## The dual graph

[`dual`](@ref)`(graph)` reverses every edge and every word
([debauche2024thesis](@cite), Def. 6.3), and the result is path-complete
exactly when the graph is (Prop. 6.6). The two orientations of De Bruijn are
each other's duals, and the dual is how every backward construction in the
package is obtained from a forward one. [Duality](@ref) is the full account.

## Words on edges

A [`WordGraph`](@ref) lets an edge read a sequence of modes
``i_1 \cdots i_k``, imposing one inequality on the product
``A_{i_k} \cdots A_{i_1}`` and nothing on the states in between. Its
[`expanded_form`](@ref) is the letter graph reading the same language with one
fresh node per intermediate step ([ahmadi2014joint](@cite), Def. 2.1), and a
word graph is path-complete exactly when its expanded form is (Def. 2.2). The
product lifts write words; for stability the edge inequality then scales as
``\gamma^{dk}`` over a word of length ``k``.

Words are sound for **stability only**: an inequality on a product bounds the
joint spectral radius, while a barrier or a value function needs every state
along the way. Safety, optimal control and [`common`](@ref) throw on a word
graph and name the expanded form.

## Cycles

A cycle reading modes ``i_1, \dots, i_k`` forces the rate to at least
``\rho(A_{i_k} \cdots A_{i_1})^{1/k}``, so [`simple_cycles`](@ref) is where a
**lower** bound on the joint spectral radius comes from,
[`jsr_lower_bound`](@ref). It is the other half of the bracket that
[Refinement: designing the graph](@ref) closes.
