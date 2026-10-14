```@meta
CurrentModule = PathCompleteCertificates
```

# Template reference

A template is the family the node functions are drawn from. See
[Templates](@ref) for the concepts, and [What works with what](@ref) for which problems accept each one.

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/abstract.jl"]
```

## Quadratic

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/quadratic.jl"]
```

## Linear copositive

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/linear_copositive.jl"]
```

## Dual copositive

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/dual_copositive.jl"]
```

## Polyhedral, fixed facets

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/parallel_faces_polyhedral.jl"]
```

## Polyhedral, free facets

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/conic_polyhedral.jl"]
```

## Sum of squares

The primitives are defined in a package extension, so `using SumOfSquares` is
required before this template can be solved with.

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/sum_of_squares.jl"]
```

## SetProg sets

The primitives are defined in a package extension, so `using SetProg` is
required before this template can be solved with.

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/catalogue/set_prog.jl"]
```
