# Conventions

The rules for code under `src/` and for the documentation. The
[Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/) is
the authority on anything not said here.

## Two axes

A certificate is a template, a graph and one edge inequality per edge, and
only the edge inequality changes from one problem to the next. The code
follows two independent axes, and neither names the other:

- **Templates** say what the node functions are. A template is an instance,
  never a type, since some carry data per node, and a vector gives one
  template per node.
- **Problems** say what the edge inequality is, one file per problem in
  `src/problems/catalogue/`.

| Problem | Edge inequality on ``(s, d, i)`` |
| :-- | :-- |
| Stability | ``V_d(A_i x) \le \gamma^\delta \, V_s(x)`` |
| Safety | ``V_d(A_i x) \le V_s(x)`` |
| Optimal control | ``\ell(x, K_s x) + V_d\big((A_i + B_i K_s) x\big) \le V_s(x)`` |

Stability and safety write their edge inequality once, in a private
`_edge_decrease`, which both builds the model and measures the slacks.
Optimal control with the quadratic template, convex only after the change of
variables to ``P^{-1}`` and ``K P^{-1}``, builds its model in them and
measures its slacks in ``P`` and ``K``. Each problem owns its certificate
type: the shared fields
live once in `CertificateData`, and what the problem certifies is a typed
field of its own, `rate`, `margin` or `gains`.

**A new problem, lift or refinement strategy is one file in the `catalogue/`
of its directory, and changes no other code**: the rest is wiring, listed in
[Extending the package](@ref). Every directory with an interface has that
shape: the interface at the top, one file per inhabitant under `catalogue/`,
named after the type without the directory's suffix.

## Templates are SetProg families

The templates rely on [SetProg.jl](https://github.com/blegat/SetProg.jl): a
template is a SetProg family, a subtype of `SetProg.AbstractVariable`, and
SetProg provides its set variables and inclusion constraints, through JuMP.
The package adds what a certificate needs:

- the primitives, declared in `src/templates/abstract.jl` and implemented for
  SetProg families in `src/problems/gauges.jl`:

  ```julia
  add_function_variables!(model, family, dimension, node)  # the node function, a set variable
  add_normalization!(model, family, V)                     # excludes V ≡ 0
  add_decrease!(model, family, V_src, V_dst, A; scale)     # scale·V_src(x) ≥ V_dst(A x) for every x
  decrease_slack(family, V_src, V_dst, A; scale)           # the same, read off a solution; 0 when tight
  homogeneity_degree(family)                               # δ: V(cx) = c^δ V(x)
  solution_value(family, V)                                # the fitted set
  ```

- what the package needs to know about a family, in `src/problems/sets.jl`:
  `is_applicable`, `is_closed_under`, `reindex`, `has_dual` and `dual`.
- the constructors, one file per template in `src/templates/catalogue/`, the
  two copositive ones sharing `copositive.jl`.

`add_decrease!` is the load-bearing primitive: stability's whole edge
inequality is one call with `scale = γ^δ`. A fitted node function is evaluated
with `node_value(problem, V, x)`, so that each problem reads the value off the
set. Every problem writes its conditions as SetProg inclusions (see
[Conditions as set inclusions](@ref)). Safety models the initial-set
inclusion and the unsafe-set disjointness, without positivity constraints on
the barriers. Optimal control computes the gains jointly with the quadratic
template only, and keeps them fixed with the other templates.

## Lifts and refinement strategies

**A lift is an operation on a graph, and `refine` an algorithm that applies
lifts.** A lift maps a path-complete graph to a path-complete graph at least
as good for every template the lift is valid for: closed under its
`requirements`, or with a dual closed under the dual operations. The same
lift can be a step of a refinement strategy and a test of `compare`, where a
simulation of ``H`` by the lifted ``G`` proves that ``H`` is at least as good
as ``G``.

```julia
# src/lifts/operations.jl: what a template is closed under and a lift requires.
Addition(), Maximum(), Minimum(), Composition(), InverseComposition()

# A lift, src/lifts/catalogue/: the forms its definition allows.
lift(L, graph)                                   # a Lifted: the graph and what each node stands for
lift(L, graph, edges)                            # at each edge, for the splits and products
lift(L, graph, node)                             # at a node, for the splits
requirements(L)                                  # the operations it needs; () by default
simulation(L, G, H; optimizer)                   # inherited; overridden where the theory decides cheaper
is_valid(L, template, system)                    # written once against the two
dual(L)                                          # a DualLift, applied on the dual graph
compare(G, H; templates, system, optimizer)      # the entry point of comparison

# A refinement strategy, src/refinements/catalogue/: one method to write.
next_graph(strategy, certificate; atol, solve)   # (lifted, its certificate or nothing), or nothing
initial_graph(strategy, system)                  # where it starts; common_graph by default
refine(template, graph, problem; strategy)       # the entry point: the loop
```

- What a lift supports is the methods it has, never a flag.
- Validity is read from the closures a template declares, never by
  dispatching on its concrete type, which would need a method per pair.
- A lift valid for a template not closed under its requirements is read
  through the dual template: the min lift is valid for the linear copositive
  template because its dual is closed under maximum. Declare a closure, and
  never override `is_valid`.
- The min, max and sum lifts are never built to decide an order: a relation
  decides the first two, and a linear program the third.
- A strategy chooses its candidates and how to select among them. The loop
  owns the solves, the stopping rules and the trace.

## The graph layer

- The certificate graph is a `HybridSystems.GraphAutomaton`, or a `WordGraph`
  when edges read words. Constrained switching is not supported: `n_modes`
  refuses a system whose automaton is not a `OneStateAutomaton`.
- `graphs/queries.jl` is the only file that touches the backing store, so
  this stays empty:

  ```
  grep -rn "_HS\.\(GraphAutomaton\|add_transition!\|Σ\)" src | grep -v queries
  ```

- Build graphs with `empty_graph`, `WordGraph` or `_empty_like`, which picks
  the kind by dispatch. A constructor returning either kind by keyword is not
  type-stable, and `Base.return_types(de_bruijn, (Int, Int))` must stay one
  concrete type.
- Three predicates. `is_path_complete` is the soundness question, decided by
  the subset construction. `is_complete` and `is_co_complete` are sufficient
  only, and decide the form of the common function. Ask about the system's
  modes, `1:n_modes(system)`: `is_path_complete(graph)` alone asks about the
  modes the graph happens to use.
- Path-completeness is PSPACE-complete, so it is checked once per solve.
  `check_path_complete = false` waives it, and must never become the default.
- Index adjacency with `_successors` and `_predecessors` rather than calling
  the star queries in a loop.
- A word graph is sound for stability only. Safety, optimal control and
  `common` throw on one and name `expanded_form`.

## Naming

- Types CamelCase, functions snake_case, constants `UPPER_CASE`, non-public
  names `_`-prefixed.
- Mutating functions end in `!`, and predicates are `is_*`.
- No `get_`, `compute_`, `build_` or `generate_` prefixes: name a function
  after what it returns. The exceptions are `get_graph`, `get_template` and
  `get_problem`, whose plain names are the variable names of
  `certify(template, graph, problem)`.
- No acronyms in public names.
- One word per concept, and the papers' word when one exists: `common`,
  `valid`, `simulation`, `tight`, `common_graph`, `alphabet`.
- No `Base.show` methods, and no `utils.jl`.

## Types and signatures

- Argument order follows the style guide, which is why the template comes
  first in `certify(template, graph, problem)`.
- No unused static parameters: `f(x::Real)`, not `f(x::T) where {T <: Real}`.
- No type piracy: Aqua fails the build on it.
- Methods over field access: `alphabet(g)`, not `g.alphabet`.
- Never hard-code `Float64` in a signature: a certificate may have to be
  exact.

## Documentation

- Every public name has a docstring, and every docstring lands in an
  `@autodocs` block under `docs/src/reference/`. [Set up](@ref) says how both
  are checked.
- The manual follows one running example, defined in
  [Systems and problems](@ref). A page keeps its data in a hidden setup block
  and says which names its code uses.
- The prose uses the code's words, one per concept: node function, edge
  inequality, common function, tight edge, lift, valid, simulation.
- The math uses the notation of the tool paper: a graph ``G = (S, E)`` with
  edges ``(s, d, i)`` from ``s`` to ``d`` labelled by mode ``i``, node functions
  ``V_s``, the rate ``\gamma``, the degree ``\delta`` of the node functions
  (``p`` is the exponent of the cost), the sets ``X_0`` and ``X_u``, the stage
  cost ``\ell``, the worst-case cost ``J_\phi`` and the robust value function
  ``J^\star``.
- Every number in the prose is the output of an example on the page. Check
  them again when the code changes.
- Graph drawings come from `docs/graph_drawing.jl`, which a page includes in
  its hidden setup block.
- [What works with what](@ref) is the single reference for the supported
  combinations and the gaps.
- Cite a result where the manual uses it, as `[key; Thm. N](@cite)`, and
  keep the [Bibliography](@ref) current. Before citing a definition or theorem
  number, read it in the paper it is attributed to.
