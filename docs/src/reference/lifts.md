```@meta
CurrentModule = PathCompleteCertificates
```

# Lift reference

A **lift** maps a path-complete graph to a path-complete graph
([debauche2021comparison](@cite), Def. 5) — that is the whole of it. It names no
template and no problem, which is why lifts sit in neither axis.

Two consumers: [`refine`](@ref) applies one where a certificate is tight, and
the ordering of two graphs, in the [Ordering reference](@ref), reads what a lift
requires. See [Lifts](@ref) for the picture.

!!! note "Soundness is free; improvement is not"
    Path-completeness is preserved, and it is the soundness condition, so a
    certificate on a lifted graph certifies the system whatever template it
    carries. What the template's closure properties decide is **validity**
    (Def. 6): whether the lift is guaranteed not to make the bound *worse*. The
    four local lifts need no such property.

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/abstract.jl"]
```

## The operations a lift may require

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["operations.jl"]
```

## The dual of a lift

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/dual.jl"]
```

## Splitting nodes along edges

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/split.jl"]
```

## Folding edges into words

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/product.jl"]
```

## The composition lift

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/composition.jl"]
```

## The subset lifts

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/subsets.jl"]
```
