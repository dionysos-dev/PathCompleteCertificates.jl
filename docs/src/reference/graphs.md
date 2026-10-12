```@meta
CurrentModule = PathCompleteCertificates
```

# Graph reference

The certificate graph is a `HybridSystems.GraphAutomaton`, the same type as the
automaton of a constrained system, or a [`WordGraph`](@ref) when its edges read
words. The argument name says which is wanted: `graph` is the certificate's,
`system` carries its own. See [Path-complete graphs](@ref) for what the
predicates mean.

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
