# CLAUDE.md

Operating guide for AI coding agents working in **PathCompleteCertificates.jl**. The developer
pages of the manual, `docs/src/developers/`, say the same for a human reader. Read this before
changing anything under `src/` or `docs/`.

## 1. What this package is

Certificates for switched linear systems built on **path-complete graphs**. A certificate is
three things: a **template**, the family the node functions are drawn from; a **labelled
graph** whose labels are the modes, with one node function `V_a` per node; and one **edge
inequality** per edge, set by the problem. When the graph is path-complete, every switching
sequence is read along a path, and the edge inequalities imply a property of the whole system.

The graph is the object of study: built, compared with another, and refined against its own
certificate. A change that makes the graph less manipulable works against the package.

## 2. The architectural contract

Only the edge inequality changes between problems, so there are **two independent axes**, not
one type hierarchy: the **template** says what the node functions are, the **problem** says
what the edge inequality is. A template supplies primitives, a problem composes them, and
neither names the other. A template is an **instance**, never a type, because some carry
per-node data; a vector gives one template per node.

**Templates are SetProg families.** A template is a subtype of `SetProg.AbstractVariable`, and
[SetProg.jl](https://github.com/blegat/SetProg.jl), a direct dependency, provides its set
variables and inclusion constraints through JuMP. The package adds the primitives, declared in
`templates/abstract.jl` and implemented for SetProg families in `problems/gauges.jl`, and the
metadata, in `problems/sets.jl`. Every primitive is public, since a contributor implements it:

```julia
# Template axis.
add_function_variables!(model, family, dimension, node)    # the node function, a set variable
add_normalization!(model, family, V)                       # excludes V ≡ 0
add_decrease!(model, family, V_src, V_dst, A; scale = 1)   # scale·V_src(x) ≥ V_dst(A x) for every x
decrease_slack(family, V_src, V_dst, A; scale = 1)         # the same, read off a solution; 0 when tight
homogeneity_degree(family)                                 # p: V(cx) = cᵖ V(x)
solution_value(family, V)                                  # the fitted SetProg set
is_applicable(family, system)                              # does the template apply at all?
is_closed_under(family, ::Operation, system)               # default false; which lifts are valid
reindex(family, origins)                                   # per-node data follows a refined graph
has_dual(family), dual(family), dual(family, set)          # the dual norms, when they exist

# Problem axis: one file per problem in problems/catalogue/.
node_value(problem, V, x)                                  # V(x), or V([x; 1]) for safety
optimization_model(template, graph, problem; optimizer, ...) # build, do not solve
certify(template, graph, problem; optimizer, ...)          # the best certificate on graph
objective, optimality_gap, edge_slacks                     # what refine reads

# The common function: each node value from the problem, their combination from the graph
# alone (graphs/observer.jl); the public method is in problems/certificate.jl.
common(graph, problem, Vs, x)
```

`add_decrease!` is the load-bearing primitive: stability's whole edge inequality is one call
with `scale = γᵖ`. Stability and safety write their edge inequality once, in a private
`_edge_decrease`, which both builds the model and measures the slacks; optimal control builds
its model in `S, Y` and measures its slacks in `P, K`. Each problem owns its certificate type;
what it certifies is a typed field (`rate`, `margin`, `gains`), and the shared fields live once
in `CertificateData`.

Stability uses the families directly. Safety and optimal control still build their programs
from quadratic matrices, behind the private `_legacy_quadratic` in
`templates/catalogue/quadratic.jl`, and accept the quadratic template only. Optimal control is
convex only after `S = P⁻¹`, `Y = KS`, and says so in place.

**A new problem, lift or refinement algorithm is one file in the `catalogue/` of its
directory, and changes no other code**; its wiring (the include, a test, a reference page,
What works with what) is listed in `docs/src/developers/extending.md`. A new template is a
SetProg family: its constructor goes in `templates/catalogue/`, and a family new to the
package needs its methods in `problems/gauges.jl` and `problems/sets.jl`.

## 3. Repository map

Each directory with an interface has the same shape: the interface files at the top, one file
per inhabitant under `catalogue/`, named after the type without the directory's suffix. Only
the module file sits at the top of `src/`.

```
src/
├── systems/      switched systems (switched.jl), runs (trajectory.jl, simulate.jl)
├── graphs/       queries.jl is THE ADAPTER over HybridSystems; words, path_completeness,
│                 dual (declares `dual` for everything), de_bruijn (common_graph is order 0),
│                 observer (and the combination rule of `common`), cycles, simulation
├── templates/    abstract.jl (the primitives) + catalogue/ (QuadraticTemplate, SumOfSquaresTemplate)
├── problems/     abstract.jl (the interface), certificate.jl (accessors, `common`),
│                 tight_edges.jl, gauges.jl (the primitives for SetProg families), sets.jl
│                 (applicability, closures, reindexing, duals), polytope_compat.jl (the
│                 copositive and polyhedral constructors) + catalogue/ (stability, safety,
│                 optimal_control)
├── lifts/        operations.jl (Addition, Maximum, Minimum, Composition, InverseComposition:
│                 what a lift requires of a template), abstract.jl, dual.jl, compare.jl
│                 + catalogue/ (twelve lifts)
└── refinements/  abstract.jl, refine.jl + catalogue/ (TightestNodeSplitting,
                  BestOfTightEdgeLifts)
```

`ext/` holds one extension per weak dependency: SumOfSquares, for the polynomial template, and
RecipesBase, for plots of a `Trajectory`. `test/` mirrors `src/`, with the template tests in
`test/problems/`; every file is standalone-runnable and listed in `TEST_FILES`. `docs/` holds
`make.jl`, `graph_drawing.jl` (the drawings of graphs shared by the pages) and `src/`. No
`utils.jl`.

## 4. Code conventions

The [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/) is the authority.
Types CamelCase, functions snake_case, constants `UPPER_CASE`, non-public names `_`-prefixed;
mutating functions end in `!`; predicates are `is_*`; no `get_`/`compute_`/`build_` prefixes;
no acronyms in public names; one word per concept, and **the papers' word** whenever one exists
(`common`, `valid`, `simulation`, `tight`, `common_graph`). The template comes first in
`certify(template, graph, problem)`, the style guide's argument order. Methods over field
access. Never hard-code `Float64` in a signature. No `Base.show`.

## 5. Documentation conventions

The documentation is part of the package; write it with the same care as the code.

- **Structure.** Introduction (index, should you use it, installation); Manual, Part I (systems
  and problems, how a certificate works, choosing a template, choosing a graph, reading a
  certificate), Part II (refining the graph, lifts), Part III (comparing graphs, duality),
  then What works with what; Tutorials (`docs/src/examples/`, Literate); Bibliography; API
  Reference; Developers. There is no separate theory section: the manual explains each result
  where it is used.
- **One running example**, defined in Systems and problems. A page keeps its data in a hidden
  `@setup` block and says which names its code uses.
- **One word per concept, the code's word**: node function, edge inequality, common function,
  tight edge, lift, valid, simulation, "at least as good". "Certificate" in general; "bound"
  and "rate" for stability only.
- **Every number in the prose is the output of an example on the page.** Check them again when
  the code changes.
- **What works with what** is the single reference for the supported combinations and the
  gaps; update it with every extension.
- **Style.** A page opens with what it is for; definitions in math when shorter; lists for
  parallel items; graph drawings from `docs/graph_drawing.jl`. No em dashes. No claim that one
  template is more or less conservative than another.
- **Citations.** Cite a result where the manual uses it, as `([key](@cite), Thm. N)`, and keep
  the Bibliography's table of what the package takes from each paper current. Read every
  definition and theorem number in the PDF in `sources/` before writing it; no citation
  without its entry in `docs/src/references.bib`.

## 6. Gotchas

- **A lift is an operation on a graph; `refine` is an algorithm that applies lifts.** Every
  lift preserves path-completeness. A lift copies node functions (splits), chains edge
  inequalities (products), combines them (min, max, sum) or composes them with the dynamics
  (compositions); the first two require nothing. What a lift supports is the methods it has
  (`lift` on the whole graph, at edges, at a node), never a flag. `compare` keeps the lifts that
  require an operation; the splits add nothing there, since `G` simulates its split through the
  origins.
- **`TightestNodeSplitting` follows Ninite & Jungers' Algorithm 1, with a finer split.** Their
  Def. 3 makes one copy per out-neighbour; `OutSplitLift` makes one copy per outgoing edge. Their
  Prop. 3 still holds for it. From `common_graph`, the first step gives the dual De Bruijn graph
  of order 1, where their lift would leave the one-node graph unchanged.
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
  solve; `check_path_complete = false` waives it and must never become the default.
- **`certify` is the single entry point.** For stability without a `rate`, it bisects to
  `rtol = 1e-6`, the default of `refine`, and keeps the certificate of its last feasible solve:
  solving again at the final rate, within solver tolerance of the boundary, may fail.
- **Stability slacks are relative.** The normalization bounds the node functions from below
  only, so their scale is arbitrary; `edge_slacks` for stability divides by `rate^p` times
  the largest node value on the unit vectors. A tight edge then has a slack of the order of
  `rtol`, and `atol = 1e-4`, at least ten times it, sees it. Absolute slacks once hid the tight
  edges of the running example, and `refine` stopped `EXHAUSTED` instead of `OPTIMAL`.
- **A fitted node function is a SetProg set, not a callable.** Evaluate it with
  `node_value(problem, V, x)`; `certificate(x)` evaluates the common function.
- **Clarabel's chordal decomposition crashes on optimal-control programs.** Pass
  `JuMP.optimizer_with_attributes(Clarabel.Optimizer, "chordal_decomposition_enable" => false)`.

## 7. Commands

```
julia --project=test test/graphs/path_completeness.jl                # one file
julia --project -e 'using Pkg; Pkg.test(; test_args = ["--fast"])'   # skips :slow suites
julia --project -e 'using Pkg; Pkg.test()'                           # the gate, before committing
julia -e 'using JuliaFormatter; format(".")'                         # required before every commit
julia --project=docs docs/make.jl                                    # everything; minutes
PCC_SKIP_LITERATE=true julia --project=docs docs/make.jl             # skips the tutorials
```

Iterate in one long-lived `julia --project=test` session with Revise; run the cold `Pkg.test()`
once at the end. For the docs, check a figure or a number with a short script, build without
the tutorials while iterating, and run one full build before committing. Nothing is exported,
so `test/docstrings.jl` is the docstring gate, and every docstring must land in an `@autodocs`
block under `docs/src/reference/`. A stale `Manifest.toml` fails `Pkg.test()` before any test
runs: delete it and `Pkg.resolve()` in the environment that failed.

## 8. Git

Never commit to `master`; branch per change; format before committing; commit or push only when
the user asks; the user opens the PR. Commit message: `ACTION module: description`, lowercase,
no trailing period, ≤ 60 chars, with `ACTION` one of `ADD`, `IMP`, `FIX`, `REF`, `REM`, `MOV`,
`REV` and the module the touched subsystem (`graphs`, `templates`, `problems`, `systems`,
`lifts`, `refinements`, `common`, `test`, `docs`, `examples`, `meta`). Do **not** add a
`Co-Authored-By` line. `plan.md`, `benchmarking.md`, the `sources/` folder (the papers and
reviewers' documents) and the paper drafts stay untracked.
