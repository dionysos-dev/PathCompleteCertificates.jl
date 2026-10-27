```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

[`refine`](@ref) is an algorithm that applies lifts where a certificate is
tight; see [Refining the graph](@ref).

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/abstract.jl"]
```

## The algorithms

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = [
    "refinements/catalogue/tightest_node_splitting.jl",
    "refinements/catalogue/best_of_tight_edge_lifts.jl",
]
```

## The loop

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/refine.jl"]
```
