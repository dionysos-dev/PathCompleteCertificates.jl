```@meta
CurrentModule = PathCompleteCertificates
```

# Template reference

Stability takes SetProg families directly. See [Choosing a template](@ref)
for their parameters and [What works with what](@ref) for support by problem.

## SetProg families

```@autodocs
Modules = [SetProg]
Pages = ["variables.jl"]
```

## Graph operations on families

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["problems/sets.jl", "problems/gauges.jl", "templates/abstract.jl"]
```

## Quadratic compatibility template

`QuadraticTemplate()` returns a native SetProg ellipsoid family. Stability
returns native fitted ellipsoids. Safety and optimal control retain their
matrix implementations behind a private adapter.

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["templates/catalogue/quadratic.jl"]
```

## Compatibility constructors

`SumOfSquaresTemplate` and the former polyhedral templates return native SetProg
families. Their names remain in PCC; there are no separate SetProg template types.

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["problems/polytope_compat.jl", "templates/catalogue/sum_of_squares.jl"]
```
