```@meta
CurrentModule = PathCompleteCertificates
```

# Problem reference

A problem fixes the inequality imposed along each edge of the graph. See
[Problems](@ref) for the concepts. A certificate `c` is callable: `c(x)`
evaluates its common function, [`common`](@ref).

## The interface and the certificates

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/abstract.jl"]
```

## Stability

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/catalogue/stability.jl"]
```

## Safety

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/catalogue/safety.jl"]
```

## Optimal control

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/catalogue/optimal_control.jl"]
```
