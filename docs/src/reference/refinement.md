```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

Neither axis, and for the same reason as [`common`](@ref): [`refine`](@ref) reads
the graph, a template and a problem at once. It is the package's one loop that
*designs* the certificate rather than solving for one on a graph you supplied.

The graph operations it drives are in the [Lift reference](@ref).

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinement/stability.jl"]
```
