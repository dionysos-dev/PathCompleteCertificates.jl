```@meta
CurrentModule = PathCompleteCertificates
```

# Template reference

The first axis: what the node functions are. See [Templates](@ref) for the
concepts, and [What works with what](@ref) for which problems accept each one.

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/abstract.jl"]
```

## Quadratic

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/quadratic.jl"]
```

## Linear copositive

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/linear_copositive.jl"]
```

## Polyhedral, fixed facets

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/polyhedral.jl"]
```

## Polyhedral, free facets

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/conic_polyhedral.jl"]
```

## Sum of squares

The primitives are defined in a package extension, so `using SumOfSquares` is
required before this template can be solved with.

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["templates/sum_of_squares.jl"]
```
