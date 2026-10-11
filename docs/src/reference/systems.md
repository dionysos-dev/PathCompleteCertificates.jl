```@meta
CurrentModule = PathCompleteCertificates
```

# Systems and the common function

Neither of these belongs to an axis. A switched system is the input to every
problem, and [`common`](@ref) reads all three of graph, template and problem.

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
