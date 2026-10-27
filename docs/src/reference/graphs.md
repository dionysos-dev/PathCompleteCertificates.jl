```@meta
CurrentModule = PathCompleteCertificates
```

# Graph reference

A certificate is built on a labelled graph: a `HybridSystems.GraphAutomaton`,
one mode per edge, or a [`WordGraph`](@ref), one word per edge. See
[Choosing a graph](@ref) for what the predicates mean.

## Queries

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/queries.jl"]
```

## Word graphs

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/words.jl"]
```

## Path-completeness

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/path_completeness.jl"]
```

## Dual graphs

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/dual.jl"]
```

## Simulation

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/simulation.jl"]
```

## Constructions

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/de_bruijn.jl", "graphs/observer.jl", "graphs/cycles.jl"]
```
