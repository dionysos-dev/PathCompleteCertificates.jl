```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

[`refine`](@ref) is an algorithm that applies lifts where a certificate is
tight; see [Graph refinement](@ref).

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/abstract.jl"]
```

## The algorithms

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = [
    "refinements/catalogue/tight_node_splitting.jl",
    "refinements/catalogue/best_tight_edge_lifting.jl",
    "refinements/catalogue/hierarchy.jl",
]
```

## The loop

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/refine.jl"]
```
