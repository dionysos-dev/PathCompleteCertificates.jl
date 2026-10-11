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
picture. A new refinement is one file answering [`scope`](@ref) and
[`refine`](@ref).

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

## Splitting nodes along edges

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/split.jl"]
```

## Folding edges into words

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/product.jl"]
```

## Strategies

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/strategies.jl"]
```

## The loop

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinements/loop.jl"]
```
