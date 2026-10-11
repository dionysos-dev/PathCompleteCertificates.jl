```@meta
CurrentModule = PathCompleteCertificates
```

# Lift reference

A **lift** is the lift of an operation: a map from path-complete graphs to
path-complete graphs whose nodes stand for combinations of the original nodes
([debauche2021comparison](@cite), Defs. 5 and 7). It exists to compare graphs:
when the lifted `G` simulates `H`, `H` is no worse than `G` for every template
closed under the operation. [`compare`](@ref) runs every lift on a pair of
graphs; see [Comparing graphs](@ref) for the picture. A new lift is one file in
`src/lifts/catalogue/` answering [`lift`](@ref) and [`requirements`](@ref).

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

## The catalogue

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = [
    "lifts/catalogue/identity.jl",
    "lifts/catalogue/min.jl",
    "lifts/catalogue/max.jl",
    "lifts/catalogue/sum.jl",
    "lifts/catalogue/composition.jl",
    "lifts/catalogue/backward_composition.jl",
]
```

## Comparing two graphs

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/compare.jl"]
```
