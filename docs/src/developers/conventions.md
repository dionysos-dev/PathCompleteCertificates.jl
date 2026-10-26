# Conventions

The rules for code under `src/`. The
[Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/) is
the authority on anything not said here.

## Two axes

A certificate is a labelled graph, a function ``V_s`` from a template at each
node and one inequality along each edge, and only the inequality changes
between problems:

| Problem | Edge inequality on ``(s, d, i)`` |
| :-- | :-- |
| Stability | ``V_d(A_i x) \le \gamma^{p}\, V_s(x)`` |
| Safety | ``B_d(A_i x) \le B_s(x)`` |
| Optimal control | ``x^\top Q x + u^\top R u + V_d(A_i x + B_i u) \le V_s(x)`` |

Stability set families live in SetProg. The problem builds SetProg variables,
normalizes their gauges, and models each edge by set inclusion. The fitted
node values are callable SetProg sets. PCC implements the certificate
primitives using SetProg's JuMP syntax:

```julia
add_function_variables!(model, family, dimension, node)
add_normalization!(model, family, variable)
add_decrease!(model, family, source, destination, A; scale)
solution_value(family, variable)
homogeneity_degree(family)
decrease_slack(family, source, destination, A; scale)
```

PCC owns the system and graph metadata in `src/problems/sets.jl`:
`is_applicable`, `is_closed_under`, `reindex`, `has_dual`, and `dual`.
Families are instances; a vector associates a family with each node.
Safety and optimal control retain a private quadratic matrix builder and its
primitives until their separate migration.

Each problem has its own certificate type. The shared fields live once in
`CertificateData`; what the problem certifies is a typed field of its own,
`rate`, `margin` or `gains`.

**A new problem, lift or refinement algorithm is one file in the
`catalogue/` of its directory, and touches nothing else.** Every directory with an
interface has that shape: the interface at the top, one file per inhabitant
under `catalogue/`, named after the type without the directory's suffix.

## Lifts and refinement algorithms

**A lift is an operation on a graph; `refine` is an algorithm that applies
lifts.** A lift maps a path-complete graph to a path-complete graph no worse
for every template closed under its `requirements`. The same lift can be a step
of a refinement algorithm and a test of `compare`, where a simulation of ``H``
by the lifted ``G`` proves ``G \le_V H``.

```julia
# src/lifts/operations.jl: what a template is closed under and a lift requires.
Addition(), Maximum(), Minimum(), Composition(), InverseComposition()

# A lift, src/lifts/catalogue/: the forms its definition gives it.
lift(L, graph)                               # a Lifted: the graph and what each node stands for
lift(L, graph, edges)                        # at each edge, for the splits and products
lift(L, graph, node)                         # at a node, for the splits
requirements(L)                              # the operations it needs; () by default
simulation(L, G, H; optimizer)               # inherited; overridden where the theory decides cheaper
is_valid(L, template, system)                # written once against the two
dual(L)                                      # a DualLift, applied on the dual graph
compare(G, H; templates, system, optimizer)  # the entry point of comparison

# A refinement algorithm, src/refinements/catalogue/: one method to write.
next_graph(algorithm, certificate; atol, solve) # the next Lifted graph, or nothing
initial_graph(algorithm, system)             # where it starts; common_graph by default
refine(template, graph, problem; algorithm)  # the entry point: the loop
```

What a lift supports is the methods it has, never a flag. Validity is read
from the closures a template declares, never by dispatching on its concrete
type, which would need a method per pair. A lift valid on a template that is
not closed under its requirements is read through the dual template: the min
lift is valid on the linear copositive template because its dual is closed
under `max`. The min, max and sum lifts are never built to decide an order: a
relation decides the first two and a linear program the third. An algorithm
chooses its candidates and how to select among them; the loop owns solving,
the stopping rules and the trace.

## The graph layer

The certificate graph is a `HybridSystems.GraphAutomaton`, or a `WordGraph`
when edges read words. Constrained switching is not supported: `n_modes`
refuses a system whose automaton is not a `OneStateAutomaton`.
`graphs/queries.jl` is the only file that touches the backing store, so this
stays empty:

```
grep -rn "_HS\.\(GraphAutomaton\|add_transition!\|Σ\)" src | grep -v queries
```

Build graphs with `empty_graph`, `WordGraph` or `_empty_like`, which picks the
kind by dispatch; a constructor returning either kind by keyword is not
type-stable, and `Base.return_types(de_bruijn, (Int, Int))` must stay one
concrete type.

There are three predicates. `is_path_complete`, every admissible
sequence readable as a path, is the soundness question, decided by the subset
construction; `is_complete` and `is_co_complete` are sufficient only, and
decide the form of the common function. Always ask with the system's
modes, `1:n_modes(system)`: `is_path_complete(graph)` alone asks about the
modes the graph happens to use. Path-completeness is PSPACE-complete, so it is checked once
per solve, and `check_path_complete = false` waives it; never make that the default.
Index adjacency with `_successors` and `_predecessors` rather than calling the
star queries in a loop.

A word graph is sound for stability only; safety, optimal control and `common`
throw on one and name `expanded_form`.

## Naming

- Types CamelCase, functions snake_case, constants `UPPER_CASE`, non-public
  names `_`-prefixed.
- Mutating functions end in `!`; predicates are `is_*`.
- No `get_`, `compute_`, `build_` or `generate_` prefixes; name a function
  after what it returns.
- No acronyms in public names.
- One word per concept, and the papers' word when one exists: `common`,
  `valid`, `simulation`, `tight`, `common_graph`, `alphabet`.
- Node functions are callable: `V(x)`.
- No `Base.show` methods, and no `utils.jl`.

## Types and signatures

- Argument order follows the style guide, which is why the template comes
  first in `certify(template, graph, problem)`.
- No unused static parameters: `f(x::Real)`, not `f(x::T) where {T <: Real}`.
- No type piracy; Aqua fails the build on it.
- Methods over field access: `alphabet(g)`, not `g.alphabet`.
- Never hard-code `Float64` in a signature; a certificate may have to be
  exact.

## Citations

Before citing a definition or theorem number in a docstring or a page, read
it in the paper it is attributed to.
