```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

A **refinement** transforms a path-complete graph into one that is no worse
for every template. [`refine`](@ref) applies refinements repeatedly where a
certificate is tight; see [Graph improvement via refinements](@ref).

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
