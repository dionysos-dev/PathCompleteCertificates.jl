```@meta
CurrentModule = PathCompleteCertificates
```

# Systems and the common function

A switched system is the input to every problem. The common function,
[`common`](@ref), is the single function the node functions of a certificate
combine into, which `certificate(x)` evaluates.

## Systems

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["systems/switched.jl"]
```

## Trajectories and simulation

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["systems/trajectory.jl", "systems/simulate.jl", "systems/closed_loop.jl"]
```

## The common function

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["common.jl"]
```
