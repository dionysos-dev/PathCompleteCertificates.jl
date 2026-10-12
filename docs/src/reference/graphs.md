```@meta
CurrentModule = PathCompleteCertificates
```

# Graph reference

A certificate is built on a labelled graph with one mode per edge, made with
[`empty_graph`](@ref), or with one word per edge, a [`WordGraph`](@ref). See
[Path-complete graphs](@ref) for what the predicates mean.

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

## Predicates

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/predicates.jl"]
```

## Languages

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/languages.jl"]
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
