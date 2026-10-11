```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

A **refinement** transforms a path-complete graph into one that is no worse
for every template; [`refine`](@ref) applies one where a certificate is tight
and repeats. The loop reads the graph, a template and a problem at once, so it
belongs to neither axis, and it names no problem: what it needs from one are
[`best_certificate`](@ref), [`objective`](@ref), [`edge_slacks`](@ref) and
[`optimality_gap`](@ref). See [Refinement: designing the graph](@ref) for the
picture. A new refinement is one file in `src/refinements/catalogue/`
answering [`scope`](@ref) and [`refine`](@ref).

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/abstract.jl"]
```

## The dual of a refinement

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/dual.jl"]
```

## The catalogue

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = [
    "refinements/catalogue/forward_edge_split.jl",
    "refinements/catalogue/backward_edge_split.jl",
    "refinements/catalogue/forward_edge_product.jl",
    "refinements/catalogue/backward_edge_product.jl",
    "refinements/catalogue/path_dependent.jl",
    "refinements/catalogue/product.jl",
]
```

## Strategies

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/strategies.jl"]
```

## The loop

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/refine.jl"]
```
