```@meta
CurrentModule = PathCompleteCertificates
```

# Lift reference

A **lift** maps a path-complete graph to a path-complete graph whose nodes
stand for combinations of the original nodes ([debauche2021comparison](@cite),
Defs. 5 and 7). Lifts are used to compare graphs. When the lifted `G` simulates
`H`, `H` is no worse than `G` for every template closed under the operation of
the lift. [`compare`](@ref) tries every lift on a pair of graphs; see
[Graph comparison via lifts](@ref).

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
