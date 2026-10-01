```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

Neither axis, and for the same reason as [`common`](@ref): [`refine`](@ref) reads
the graph, a template and a problem at once. It is the package's one loop that
*designs* the certificate rather than solving for one on a graph you supplied,
and it names no problem: what it needs from one are the methods
[`best_certificate`](@ref), [`objective`](@ref), [`edge_slacks`](@ref) and
[`optimality_gap`](@ref) of the problem interface.

The graph operations it drives are in the [Lift reference](@ref).

## The loop

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinement/loop.jl"]
```

## Strategies

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinement/strategies.jl"]
```
