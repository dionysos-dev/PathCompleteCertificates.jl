```@meta
CurrentModule = PathCompleteCertificates
```

# Graph reference

The path-complete graph is a `HybridSystems.GraphAutomaton` — the same type as
the system's own automaton — or a [`WordGraph`](@ref) when its edges read words.
The package owns no graph algorithms of its own beyond these: the queries,
predicates and constructions layered over the backing store, all of them
reachable through the adapter in `graphs/queries.jl` and nothing else.

See [Path-complete graphs](@ref) for what they mean and what they license.

!!! note "The certificate graph and the system's automaton are the same type"
    Both are a `GraphAutomaton`, so nothing stops you passing one where the
    other is expected. The argument name tells you which is wanted: `graph` is
    the certificate's, `system` carries its own.

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
