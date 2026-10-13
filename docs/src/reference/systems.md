```@meta
CurrentModule = PathCompleteCertificates
```

# Systems and the common function

A switched system is the input to every problem. The common function,
[`common`](@ref), combines the node functions of a certificate into a single
function. A certificate `c` is callable: `c(x)` evaluates its common function
at `x`.

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
