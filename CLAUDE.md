# CLAUDE.md

Operating guide for AI coding agents working in **PathCompleteCertificates.jl**. The developer
pages of the manual, `docs/src/developers/`, say the same for a human reader. Read this before
changing anything under `src/`.

## 1. What this package is

Certificates for switched systems built on **path-complete graphs**. A certificate is three
things: a **labelled graph** whose labels are the modes, a function `V_s` drawn from a
**template** at each node, and one **inequality along each edge**. When the graph is
path-complete, every switching sequence is readable as a path and the local inequalities imply a
property of the whole system.

The graph is the object of study: built, compared with another, and refined against its own
certificate. A change that makes the graph less manipulable works against the package.

## 2. The architectural contract

Only the edge inequality changes between problems, so there are **two independent axes**, not
one type hierarchy: the **template** (`src/templates/`) says what the node functions are, the
**problem** (`src/problems/`) says what the edge inequality is. A template supplies primitives,
a problem composes them, and neither names the other. A template is an **instance**, never a
type, because some carry per-node data. Every primitive is public, since a user implements it:

```julia
# Template axis: one file per template, answering all of it.
add_function_variables!(model, template, dim, node)        # the node function V_s, well defined
add_decrease!(model, template, V_src, V_dst, map; scale = 1)
                                                           # scale·V_src(x) − V_dst(map·x) ≥ 0
decrease_slack(template, V_src, V_dst, map; scale = 1)     # the same, read off a solution; 0 when tight
add_normalization!(model, template, V)                     # excludes V ≡ 0
homogeneity_degree(template)                               # p: V(cx) = cᵖ V(x)
solution_value(template, V)                                # variables -> a callable node function
is_applicable(template, system)                            # default true; does the template apply at all?
is_closed_under(template, ::Operation, system)             # default false; which lifts are valid
reindex(template, origins)                                 # per-node data follows a refined graph
has_dual(template), dual(template), dual(template, V)      # the dual norms, when they exist

# Problem axis: one file per problem, composing the above.
node_value(template, problem, V, x)                           # V(x), or V([x; 1]) for safety
optimization_model(template, graph, problem; optimizer, ...)   # build, do not solve
certify(template, graph, problem; optimizer, ...)             # build, solve, extract
best_certificate, objective, optimality_gap, edge_slacks       # what refine reads

# The common function: each node value from the problem (node_value), their combination
# from the graph alone (graphs/observer.jl); the public method is in problems/certificate.jl.
common(template, graph, problem, Vs, x)
```

`add_decrease!` is the load-bearing primitive: the cone that quantifies an inequality over
all `x` depends on the template and on nothing else, so stability's whole edge condition is one
call with `scale = γᵖ`. Optimal control is the one exception, convex only after `S = P⁻¹`,
`Y = KS`, and says so in place. Each problem writes its edge condition once, in a private
`_edge_decrease`, which both builds the model and measures the slacks.

Each problem owns its certificate type; what it certifies is a typed field (`rate`, `margin`,
`gains`), and the shared fields live once in `CertificateData`.

**A new template, problem, lift or refinement algorithm is one file in the `catalogue/` of its
directory, and touches nothing else.**

## 3. Repository map

Each directory with an interface has the same shape: the interface files at the top, one file
per inhabitant under `catalogue/`, named after the type without the directory's suffix.

```
src/
├── systems/             switched systems, runs, the dual system
├── graphs/              queries.jl is THE ADAPTER over HybridSystems; words,
│                        path_completeness, dual (also declares `dual` for everything),
│                        de_bruijn (common_graph is order 0), observer (and the combination
│                        rule of `common`), cycles, simulation
├── templates/           abstract.jl + catalogue/ (seven templates; sum_of_squares and set_prog in ext/)
├── problems/            abstract.jl (the interface), certificate.jl (accessors, `common`),
│                        tight_edges.jl + catalogue/ (stability, safety, optimal_control)
├── lifts/               the lifts of a graph: operations.jl (Addition, Maximum, Minimum,
│                        Composition, InverseComposition: what a lift requires of a template),
│                        abstract.jl, dual.jl, compare.jl + catalogue/
└── refinements/         the algorithms that apply lifts: abstract.jl, refine.jl + catalogue/
```

Only the module file sits at the top of `src/`; every other file belongs to a directory.

`ext/` holds one extension per weak dependency. `test/` mirrors `src/` directory for directory,
every file standalone-runnable and listed in `TEST_FILES`. `docs/src/examples/` are executed by
the docs build. No `utils.jl`.

## 4. Conventions

The [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/) is the authority.
Types CamelCase, functions snake_case, constants `UPPER_CASE`, non-public names `_`-prefixed;
mutating functions end in `!`; predicates are `is_*`; no `get_`/`compute_`/`build_` prefixes;
no acronyms in public names; one word per concept, and **the papers' word** whenever one
exists (`common`, `valid`, `simulation`, `tight`, `common_graph`). The template comes first in
`certify(template, graph, problem)`, the style guide's argument order. Methods over field
access. Never hard-code `Float64` in a signature. No `Base.show`.

## 5. Gotchas

- **A lift is an operation on a graph; `refine` is an algorithm that applies lifts.** Every
  lift preserves path-completeness; its validity is read from the template's closures through
  `is_valid`, written once, and a lift that copies node functions or chains edges requires
  nothing. What a lift supports is the methods it has (`lift` on the whole graph, at edges, at
  a node), never a flag. `compare` keeps the lifts that require an operation; the splits add
  nothing there, since `G` simulates its split through the origins.
- **`TightNodeSplitting` is Ninite & Jungers' Algorithm 1 exactly.** Its lift is their Def. 3,
  one copy per successor, so it starts from the dual De Bruijn graph of order 1, as their
  experiments do: on the one-node graph the forward lift changes nothing.
- **Min, max and sum lifts are never built to decide.** A relation decides min, the relation on
  the duals decides max, a linear program decides the sum lift over every size.
- **No override of `is_valid`.** A lift valid on a template that is not closed under its
  requirements is read through the dual: the min lift is valid on the linear copositive template
  (Debauche, Thm. 7.43) because the dual copositive template is closed under max. Declare a
  closure, never an override.
- **Duality is an involution on everything**: graphs, systems, templates, certificates, lifts,
  operations. Every backward lift is `dual` of a forward one.
- **A word graph is sound for stability only.** Safety, optimal control and `common` throw on a
  `WordGraph` and name `expanded_form`.
- **The adapter invariant.** Nothing outside `graphs/queries.jl` touches HybridSystems' graph
  internals; `grep -rn "_HS\.\(GraphAutomaton\|add_transition!\|Σ\)" src | grep -v queries` is
  empty. Build graphs with `empty_graph`, `WordGraph` or `_empty_like`, which chooses the kind
  by dispatch, never by keyword, so the constructors stay type-stable.
- **Three predicates.** `is_path_complete` is the soundness question, decided by the subset
  construction; `is_complete` and `is_co_complete` are sufficient only, and decide the form of
  `common`. Always pass the system's modes, `1:n_modes(system)`: `is_path_complete(graph)` alone
  asks about the modes the graph happens to use. Constrained switching is not supported;
  `n_modes` refuses a system whose automaton is not a `OneStateAutomaton`.
- **Index adjacency before scanning it.** `_successors` and `_predecessors` are built once;
  the star queries cost the degree. Path-completeness is PSPACE-complete, checked once per
  solve; `path_complete = false` waives it and must never become the default.
- **Verify every citation in the PDF before writing it.** No theorem number without reading it.

## 6. Commands

```
julia --project=test test/graphs/path_completeness.jl                # one file
julia --project -e 'using Pkg; Pkg.test(; test_args = ["--fast"])'   # skips :slow suites
julia --project -e 'using Pkg; Pkg.test()'                           # the gate, before committing
julia -e 'using JuliaFormatter; format(".")'                         # required before every commit
julia --project=docs docs/make.jl                                    # runs the examples; minutes
PCC_SKIP_LITERATE=true julia --project=docs docs/make.jl             # prose only
```

Iterate in one long-lived `julia --project=test` session with Revise; run the cold `Pkg.test()`
once at the end. Nothing is exported, so `test/docstrings.jl` is the docstring gate, and every
docstring must land in an `@autodocs` block under `docs/src/reference/`. A stale
`Manifest.toml` fails `Pkg.test()` before any test runs: delete it and `Pkg.resolve()` in the
environment that failed.

## 7. Git

Never commit to `master`; branch per change; format before committing; the user opens the PR.
Commit message: `ACTION module: description`, lowercase, no trailing period, ≤ 60 chars, with
`ACTION` one of `ADD`, `IMP`, `FIX`, `REF`, `REM`, `MOV`, `REV` and the module the touched
subsystem (`graphs`, `templates`, `problems`, `systems`, `lifts`, `refinements`, `common`,
`test`, `docs`, `examples`, `meta`). Do **not** add a `Co-Authored-By` line. `plan.md` and
the `sources/` folder, the papers and reviewers' documents, stay untracked.
