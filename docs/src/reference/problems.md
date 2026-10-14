```@meta
CurrentModule = PathCompleteCertificates
```

# Problem reference

A problem fixes the inequality imposed along each edge of the graph. See
[Problems](@ref) for the concepts. A certificate `c` is callable: `c(x)`
evaluates its common function, [`common`](@ref).

## The interface

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/abstract.jl"]
```

## Certificates

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/certificate.jl"]
```

## Tight edges

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["problems/tight_edges.jl"]
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
