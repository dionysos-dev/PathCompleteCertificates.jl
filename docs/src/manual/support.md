```@meta
CurrentModule = PathCompleteCertificates
```

# What works with what

Stability accepts SetProg families directly. Safety and optimal control retain
[`QuadraticTemplate`](@ref); their SetProg migration is deferred.

| Family | Stability | Refinement |
| :-- | :-: | :-: |
| symmetric ellipsoid | ✓ | ✓ |
| positive simplex or box | ✓ on positive systems | ✓ |
| parallelotope or conic polytope | ✓ | ✓ |
| polynomial set | ✓ with `using SumOfSquares` | |
| piecewise ellipsoid or polytope | ✓ | |

Refinement requires [`decrease_slack`](@ref). Fitted polynomial and general
piecewise slacks need a separate optimization and are not implemented.
See [Templates](@ref) for closures governing [`compare`](@ref).

Stability accepts [`WordGraph`](@ref). Safety and optimal control require one
mode per edge; optimal control requires a complete graph.
