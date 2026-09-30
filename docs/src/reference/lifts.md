```@meta
CurrentModule = PathCompleteCertificates
```

# Lift reference

A **lift** maps a path-complete graph to a path-complete graph
([debauche2021comparison](@cite), Def. 5) — that is the whole of it. It names no
template and no problem, which is why lifts sit in neither axis.

Two consumers: [`refine`](@ref) applies one to get a better graph, and the
*ordering* of two graphs, which the paper above uses them for and which is not
implemented yet.

!!! note "Soundness is free; improvement is not"
    Path-completeness is preserved, and it is the soundness condition, so a
    certificate on a lifted graph certifies the system whatever template it
    carries. What the template's closure properties decide is **validity**
    (Def. 6): whether the lift is guaranteed not to make the bound *worse*. The
    forward lifts need no such property.

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/abstract.jl"]
```

## The forward lifts

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/forward.jl"]
```
