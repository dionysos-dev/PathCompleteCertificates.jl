```@meta
CurrentModule = PathCompleteCertificates
```

# Refinement reference

Neither axis, and for the same reason as [`common`](@ref): [`refine`](@ref) reads
the graph, a template and a problem at once. It is the package's one loop that
*designs* the certificate rather than solving for one on a graph you supplied.

The lifts below are pure graph transforms, so they are usable on their own.
Whether a lift may be applied without losing soundness is a property of the
**template**, not of the graph — see the warning under [`refine`](@ref).

## The lifts

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinement/lift.jl"]
```

## The loop

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["refinement/stability.jl"]
```
