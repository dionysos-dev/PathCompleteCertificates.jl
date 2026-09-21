```@meta
CurrentModule = PathCompleteCertificates
```

# Graph reference

The path-complete graph is a `HybridSystems.GraphAutomaton` — the same type as
the system's own automaton. The package owns no graph type; these are the
queries, predicates and constructions layered over it.

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

## Predicates

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/predicates.jl"]
```

## Constructions

```@autodocs
Modules = [PathCompleteCertificates]
Pages   = ["graphs/de_bruijn.jl", "graphs/observer.jl"]
```
