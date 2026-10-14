```@meta
CurrentModule = PathCompleteCertificates
```

# Template reference

Stability takes SetProg families directly. See [Templates](@ref) for their
parameters and [What works with what](@ref) for support by problem.

## SetProg families

```@autodocs
Modules = [SetProg]
Pages = ["gauges.jl"]
```

## Graph operations on families

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["problems/sets.jl", "templates/abstract.jl"]
```

## Legacy quadratic template for safety and optimal control

```@autodocs
Modules = [PathCompleteCertificates]
Pages = ["templates/catalogue/quadratic.jl"]
```
