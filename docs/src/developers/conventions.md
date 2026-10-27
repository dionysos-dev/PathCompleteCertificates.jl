# Conventions

The rules for code under `src/` and for the documentation. The
[Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/) is
the authority on anything not said here.

## Two axes

A certificate is a template, a graph and one inequality per edge, and only the
inequality changes from one problem to the next. The code follows two
independent axes, and neither names the other:

- **templates** say what the node functions are; a template is an instance,
  never a type, since some carry data per node, and a vector gives one
  template per node;
- **problems** say what the edge inequality is, one file per problem in
  `src/problems/catalogue/`.

| Problem | Edge inequality on ``(a, b, i)`` |
| :-- | :-- |
| Stability | ``V_b(A_i x) \le \gamma^{p}\, V_a(x)`` |
| Safety | ``V_b(A_i x) \le V_a(x)``, in the coordinates ``[x; 1]`` |
| Optimal control | ``x^\top Q x + u^\top R u + V_b(A_i x + B_i u) \le V_a(x)``, with ``u = K_a x`` |

Stability and safety write their edge inequality once, in a private
`_edge_decrease`, which both builds the model and measures the slacks.
Optimal control, convex only after the change of variables ``S = P^{-1}``,
``Y = K S``, builds its model in ``S`` and ``Y`` and measures its slacks in
``P`` and ``K``. Each problem owns its certificate type: the shared fields
live once in `CertificateData`, and what the problem certifies is a typed
field of its own, `rate`, `margin` or `gains`.

**A new problem, lift or refinement algorithm is one file in the `catalogue/`
of its directory, and changes no other code**: the rest is wiring, listed in
[Extending the package](@ref). Every directory with an interface has that
shape: the interface at the top, one file per inhabitant under `catalogue/`,
named after the type without the directory's suffix. The exception is the
templates, whose copositive and polyhedral constructors live in
`src/problems/polytope_compat.jl`.

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
  homogeneity_degree(family)                               # p: V(cx) = cᵖ V(x)
  solution_value(family, V)                                # the fitted set
  ```

- what the package needs to know about a family, in `src/problems/sets.jl`:
  `is_applicable`, `is_closed_under`, `reindex`, `has_dual` and `dual`;
- the constructors: `QuadraticTemplate` and `SumOfSquaresTemplate` in
  `src/templates/catalogue/`, the copositive and polyhedral ones in
  `src/problems/polytope_compat.jl`.

`add_decrease!` is the load-bearing primitive: stability's whole edge
inequality is one call with `scale = γᵖ`. A fitted node function is a SetProg
set, evaluated with `node_value(problem, V, x)`, so that each problem chooses
its coordinates. Stability uses the families directly; safety and optimal
control still build their programs from quadratic matrices, behind a private
builder, and accept the quadratic template only.

## Lifts and refinement algorithms

**A lift is an operation on a graph; `refine` is an algorithm that applies
lifts.** A lift maps a path-complete graph to a path-complete graph at least
as good for every template the lift is valid for: closed under its
`requirements`, or with a dual closed under the dual operations. The same
lift can be a step of a refinement algorithm and a test of `compare`, where a
simulation of ``H`` by the lifted ``G`` proves ``G \le_V H``.

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

# A refinement algorithm, src/refinements/catalogue/: one method to write.
next_graph(algorithm, certificate; atol, solve)  # (lifted, its certificate or nothing), or nothing
initial_graph(algorithm, system)                 # where it starts; common_graph by default
refine(template, graph, problem; algorithm)      # the entry point: the loop
```

- What a lift supports is the methods it has, never a flag.
- Validity is read from the closures a template declares, never by
  dispatching on its concrete type, which would need a method per pair.
- A lift valid for a template not closed under its requirements is read
  through the dual template: the min lift is valid for the linear copositive
  template because its dual is closed under maximum. Declare a closure; never
  override `is_valid`.
- The min, max and sum lifts are never built to decide an order: a relation
  decides the first two, and a linear program the third.
- An algorithm chooses its candidates and how to select among them; the loop
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
  the kind by dispatch; a constructor returning either kind by keyword is not
  type-stable, and `Base.return_types(de_bruijn, (Int, Int))` must stay one
  concrete type.
- Three predicates: `is_path_complete`, the soundness question, decided by
  the subset construction; `is_complete` and `is_co_complete`, sufficient
  only, which decide the form of the common function. Ask about the system's
  modes, `1:n_modes(system)`: `is_path_complete(graph)` alone asks about the
  modes the graph happens to use.
- Path-completeness is PSPACE-complete, so it is checked once per solve;
  `check_path_complete = false` waives it, and must never become the default.
- Index adjacency with `_successors` and `_predecessors` rather than calling
  the star queries in a loop.
- A word graph is sound for stability only; safety, optimal control and
  `common` throw on one and name `expanded_form`.

## Naming

- Types CamelCase, functions snake_case, constants `UPPER_CASE`, non-public
  names `_`-prefixed.
- Mutating functions end in `!`; predicates are `is_*`.
- No `get_`, `compute_`, `build_` or `generate_` prefixes; name a function
  after what it returns.
- No acronyms in public names.
- One word per concept, and the papers' word when one exists: `common`,
  `valid`, `simulation`, `tight`, `common_graph`, `alphabet`.
- No `Base.show` methods, and no `utils.jl`.

## Types and signatures

- Argument order follows the style guide, which is why the template comes
  first in `certify(template, graph, problem)`.
- No unused static parameters: `f(x::Real)`, not `f(x::T) where {T <: Real}`.
- No type piracy; Aqua fails the build on it.
- Methods over field access: `alphabet(g)`, not `g.alphabet`.
- Never hard-code `Float64` in a signature; a certificate may have to be
  exact.

## Documentation

- Every public name has a docstring, and every docstring lands in an
  `@autodocs` block under `docs/src/reference/`; [Set up](@ref) says how both
  are checked.
- The manual follows one running example, defined in
  [Systems and problems](@ref). A page keeps its data in a hidden setup block
  and says which names its code uses.
- The prose uses the code's words, one per concept: node function, edge
  inequality, common function, tight edge, lift, valid, simulation.
- Every number in the prose is the output of an example on the page; check
  them again when the code changes.
- Graph drawings come from `docs/graph_drawing.jl`, which a page includes in
  its hidden setup block.
- [What works with what](@ref) is the single reference for the supported
  combinations and the gaps.
- Cite a result where the manual uses it, as `([key](@cite), Thm. N)`, and
  keep the [Bibliography](@ref) current. Before citing a definition or theorem
  number, read it in the paper it is attributed to.
