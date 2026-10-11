# CLAUDE.md

Operating guide for AI coding agents working in **PathCompleteCertificates.jl**. The long
version, with the history and the measurements behind each rule, is
`docs/src/developers/conventions.md`. Read this before changing anything under `src/`.

## 1. What this package is

Certificates for switched systems built on **path-complete graphs**. A certificate is always
three things: a **labelled graph** whose labels are the modes, a function `V_s` drawn from a
**template** at each node, and one **inequality along each edge**. When the graph is
path-complete, every switching sequence is readable as a path, and the local inequalities imply a
property of the whole system; otherwise they certify the property over the language the graph
reads, which is less.

Unlike SwitchOnSafety.jl and the JSR Toolbox, which use a path-complete graph as an internal
device for a bound, here **the graph is the object of study**: built, compared with another, and
refined against its own certificate. A change that makes the graph less manipulable works
against the package.

## 2. The architectural contract

Only the edge inequality changes between problems: stability `V_s(x) ≥ γ⁻ᵈ V_d(A_i x)`, safety
the invariance condition, optimal control `V_s(x) ≥ c(x) + V_d(f_i(x))`. So there are **two
independent axes**, not one type hierarchy:

- **template** (`src/templates/`): what the node functions are;
- **problem** (`src/problems/`): what the edge inequality says.

A template supplies primitives; a problem composes them. Neither names the other. A template is
an **instance**, never a type, because some carry per-node data. Every primitive is public,
since a user implements it:

```julia
# Template axis: one file per template, answering all of it.
add_function_variables!(model, template, dim, node)        # the node function V_s
add_domination!(model, template, V_src, V_dst, map; scale = 1, margin = 0)
                                                           # scale·V_src(x) − V_dst(map·x) ≥ margin‖x‖ᵈ
domination_slack(template, V_src, V_dst, map; scale = 1)   # the same, read off a solution; 0 when tight
add_nonnegativity!(model, template, V)
add_normalization!(model, template, V)                     # excludes V ≡ 0
homogeneity_degree(template)                               # d: V(cx) = cᵈ V(x)
solution_value(template, V)                                # variables -> a callable node function
check_dynamics(template, A)                                # is the template applicable at all?
is_closed_under(template, ::Operation, system)             # default false; what lifts are valid
reindex(template, origins)                                 # per-node data follows a refined graph
has_dual(template), dual(template), dual(template, V)      # the dual norms, when they exist

# Problem axis: one file per problem, composing the above.
add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; rate = 1)
optimization_model(template, graph, problem; optimizer, ...)   # build, do not solve
certify(template, graph, problem; optimizer, ...)             # build, solve, extract
best_certificate, objective, optimality_gap, edge_slacks       # what `refine` reads

# The common function (src/common.jl): dispatches on the graph, so neither axis owns it.
common(template, graph, problem, Vs, x)   # complete → min; co-complete → max; else min of max over the observer
```

`add_domination!` is the load-bearing primitive: quantifying an inequality over all `x` needs
a lifting into a cone that is template-specific, yet it is problem-agnostic, so stability's
whole edge condition is one call with `scale = γᵈ`. Optimal control is the one exception, convex
only after `S = P⁻¹`, `Y = KS`, and it is documented in place rather than smoothed over.

Each problem owns its certificate type; what it certifies is a **typed field** (`rate`,
`margin`, `gains`), and the six shared fields live once in `CertificateData`.

**A new template, problem, lift or refinement is one file in the `catalogue/` of its directory,
and touches nothing else.** `grep -c '^function add_edge_constraint!' src/problems/catalogue/*.jl`
returning 1 everywhere is the check.

## 3. Repository map

Each directory with an interface has the same shape: `abstract.jl` and the other interface
files at the top, one file per inhabitant under `catalogue/`, named after the type without the
directory's suffix.

```
src/
├── operations.jl        Addition, Maximum, Minimum, Composition, InverseComposition; `dual`
├── systems/             switched systems, runs, the dual system
├── graphs/              queries.jl is THE ADAPTER over HybridSystems; words, predicates,
│                        languages, dual, de_bruijn, observer, cycles, simulation
├── templates/           abstract.jl + catalogue/ (six templates; sum_of_squares in ext/)
├── problems/            abstract.jl + catalogue/ (stability, safety, optimal_control)
├── lifts/               COMPARING graphs: abstract.jl, dual.jl, compare.jl + catalogue/
│                        (identity, min, max, sum, composition, backward_composition)
├── refinements/         IMPROVING a graph: abstract.jl, dual.jl, strategies.jl, refine.jl
│                        + catalogue/ (the four atoms, path_dependent, product)
└── common.jl            `common`: reads graph, template and problem, so belongs to neither axis
```

`ext/` holds one extension per weak dependency. `test/` mirrors `src/` at the level of its
directories, every file standalone-runnable, new files listed in `TEST_FILES`.
`docs/src/examples/` are executed by the docs build. No `utils.jl`.

## 4. Conventions

The [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/) is the authority.
Types CamelCase, functions snake_case, constants `UPPER_CASE`, non-public names `_`-prefixed;
mutating functions end in `!`; predicates are `is_*`; no `get_`/`compute_`/`build_` prefixes;
no acronyms in public names; one word per concept, and **the papers' word** whenever one
exists (`common`, `valid`, `simulation`, `tight`, `common_graph`). Argument order is the
style guide's, which is why the template comes first in `certify(template, graph, problem)`.
Prefer methods over field access. Never hard-code `Float64` in a signature. No `Base.show`.

## 5. Gotchas

- **A lift compares; a refinement improves.** Both preserve path-completeness. A lift is the
  lift of an operation, its validity is read from the template's closures through `is_valid`,
  written once, and `simulation(lift, G, H)` decides the order `G ≤_V H`. A refinement is valid
  for every template by construction and has no `requirements`; do not add them. The
  composition lift is the one object on both sides.
- **Min, max and sum lifts are never built to decide.** The relation decides min, the relation
  on the duals decides max, the linear program decides the sum lift over every size.
- **One override of `is_valid`** exists, for the min lift on the copositive norms (Debauche,
  Thm. 7.43). Add another only with a theorem to cite.
- **Duality is an involution on everything**: graphs, systems, templates, certificates, lifts,
  refinements, operations. Every backward construction is `dual` of a forward one.
- **A word graph is sound for stability only.** Safety, optimal control and `common` throw on a
  `WordGraph` and name `expanded_form`.
- **The adapter invariant.** Nothing outside `graphs/queries.jl` touches HybridSystems' graph
  internals; `grep -rn "_HS\.\(GraphAutomaton\|add_transition!\|Σ\)" src | grep -v queries` is
  empty. Build graphs with `empty_graph`, `WordGraph` or `_empty_like`, which chooses the kind
  by dispatch, never by keyword: a union-typed constructor once crashed Julia 1.12.
- **Three predicates.** `is_path_complete` (every word readable, decided by the subset
  construction) is the soundness question; `is_complete` and `is_co_complete` are sufficient
  only, and what they license is what `common` dispatches on. Always pass the system's
  alphabet: `is_path_complete(graph)` alone asks about the labels the graph happens to use.
- **Index adjacency before scanning it.** `_successors` and `_predecessors` are built once;
  the star queries cost the degree. Path-completeness is PSPACE-complete, checked once per
  solve, and `path_complete = false` waives it: never make that the default.
- **`refute` is not `certify`.** Sampling finds violations; it proves nothing.
- **Verify every citation in the PDF before writing it.** No theorem number without reading it.

## 6. Commands

```
julia --project=test test/graphs/predicates.jl                       # narrowest scope first
julia --project -e 'using Pkg; Pkg.test(; test_args = ["--fast"])'   # skips :slow suites
julia --project -e 'using Pkg; Pkg.test()'                           # the gate, before committing
julia -e 'using JuliaFormatter; format(".")'                         # REQUIRED before every commit
julia --project=docs docs/make.jl                                    # runs the examples; minutes
PCC_SKIP_LITERATE=true julia --project=docs docs/make.jl             # prose only
```

Iterate in one long-lived `julia --project=test` session with Revise; run the cold `Pkg.test()`
once at the end. `test/docstrings.jl` is the docstring gate, since nothing is exported; every
docstring must also land in an `@autodocs` block under `docs/src/reference/`. A stale
`Manifest.toml` fails `Pkg.test()` before any test runs: `rm` it and `Pkg.resolve()` in the
environment that failed.

## 7. Git

Never commit to `master`; branch per change; format before committing; the user opens the PR.
Commit message: `ACTION module: description`, lowercase, no trailing period, ≤ 60 chars, with
`ACTION` one of `ADD`, `IMP`, `FIX`, `REF`, `REM`, `MOV`, `REV` and the module the touched
subsystem (`graphs`, `templates`, `problems`, `systems`, `lifts`, `refinements`, `common`,
`test`, `docs`, `examples`, `meta`). Do **not** add a `Co-Authored-By` line. `plan*.md`, the
`lifts/` folder and reviewers' documents stay untracked.
