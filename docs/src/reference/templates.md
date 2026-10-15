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

## Legacy quadratic template for safety and optimal control

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
