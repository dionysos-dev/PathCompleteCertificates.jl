```@meta
CurrentModule = PathCompleteCertificates
```

# Lift reference

A **lift** is an operation on a path-complete graph whose result is at least
as good for every template the lift is valid for. [`refine`](@ref) applies
lifts, and [`compare`](@ref) uses them to order two graphs; see
[Lifts](@ref).

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/abstract.jl"]
```

## The operations a lift may require

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/operations.jl"]
```

## The dual of a lift

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/dual.jl"]
```

## Splits

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = [
    "lifts/catalogue/out_split.jl",
    "lifts/catalogue/in_split.jl",
    "lifts/catalogue/path_dependent.jl",
]
```

## Products

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = [
    "lifts/catalogue/forward_product.jl",
    "lifts/catalogue/backward_product.jl",
    "lifts/catalogue/product.jl",
]
```

## Combinations

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/catalogue/min.jl", "lifts/catalogue/max.jl", "lifts/catalogue/sum.jl"]
```

## Compositions

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/catalogue/composition.jl", "lifts/catalogue/backward_composition.jl"]
```

## The identity

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/catalogue/identity.jl"]
```

## Comparing two graphs

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["lifts/compare.jl"]
```
