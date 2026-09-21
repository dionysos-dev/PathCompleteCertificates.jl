```@meta
CurrentModule = PathCompleteCertificates
```

# Path-complete graphs

The graph is the object of study here, not an internal device.

## The soundness condition

A graph is **path-complete** for an alphabet when every finite switching
sequence over it is readable as a path ([philippe2017path](@cite), Def. II.1).
Without it the edge inequalities certify nothing, so every entry point checks.

```@docs; canonical=false
is_path_complete
```

!!! danger "Path-completeness is relative to an alphabet"
    `is_path_complete(graph)` asks only about the labels the graph happens to
    use, so a graph that never mentions a mode passes trivially and certifies
    nothing about it. That once returned a bound of `0.906` for a system whose
    joint spectral radius is at least `3`.

    Pass the system's alphabet: `is_path_complete(graph, 1:n_modes)`. Every
    problem does this for you.

## Three predicates

| Predicate | Source | Meaning |
| :-- | :-- | :-- |
| [`is_path_complete`](@ref) | Def. II.1 | **every** switching sequence is readable as a path |
| [`is_complete`](@ref) | Def. III.2 | every node has an *outgoing* edge for every mode |
| [`is_co_complete`](@ref) | Def. III.2 | every node has an *incoming* edge for every mode |

The last two are **sufficient, not necessary**: a graph can read every word
without every node reading every letter. "Is this a valid certificate?" is
always [`is_path_complete`](@ref). None of the three is graph-theoretic
completeness.

What the sufficient conditions buy is a cheaper check and a simpler aggregation.

## Aggregation

A certificate gives one function per node; [`common`](@ref) combines them into
the one function that certifies the system. Minimum for a complete graph
(Cor. III.3), maximum for co-complete, minimum-of-maxima over the observer graph
otherwise (Thm III.8) — it picks for you.

```@docs; canonical=false
common
```

## Building one

```@docs; canonical=false
de_bruijn
```

Order `k` over `m` modes has `mᵏ` nodes and remembers the last `k` modes. Higher
order buys a tighter bound at exponential cost. `orientation` decides which
sufficient condition holds, and so which aggregation applies.

## When the check costs you

Deciding path-completeness is PSPACE-complete in general. On De Bruijn graphs it
is cheap, and a complete or co-complete graph settles it without the subset
construction at all. If you do hit the cost, `path_complete = false` on any
entry point skips the check.

!!! warning "`path_complete = false` is an assertion, not a question"
    Assert it wrongly and you get a certificate that certifies nothing — no
    error, no warning.
