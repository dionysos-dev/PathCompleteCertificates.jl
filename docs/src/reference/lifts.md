```@meta
CurrentModule = PathCompleteCertificates
```

# Lift reference

A **lift** is an operation on a path-complete graph whose result is no worse
for every template closed under the operations it requires. [`refine`](@ref)
applies lifts, and [`compare`](@ref) uses them to order two graphs; see
[Lifts](@ref).

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
    "lifts/catalogue/forward_split.jl",
    "lifts/catalogue/backward_split.jl",
    "lifts/catalogue/forward_product.jl",
    "lifts/catalogue/backward_product.jl",
    "lifts/catalogue/path_dependent.jl",
    "lifts/catalogue/product.jl",
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
