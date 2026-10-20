```@meta
CurrentModule = PathCompleteCertificates
```

# Template reference

Stability takes SetProg families directly. See [Templates](@ref) for their
parameters and [What works with what](@ref) for support by problem.

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

`QuadraticTemplate()` delegates stability modeling to SetProg while preserving
the existing fitted quadratic functions. Safety and optimal control retain
their implementations.

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["templates/catalogue/quadratic.jl"]
```

## Compatibility constructors

The former polyhedral templates are constructors returning native SetProg
families. Their names remain in PCC; there are no separate SetProg template types.

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["problems/polytope_compat.jl"]
```
