# CLAUDE.md

Operating guide for AI coding agents (Claude Code) working in
**PathCompleteCertificates.jl**. Read this before making changes.

---

## 1. What this package is

Certificates for switched systems built on **path-complete graphs**.

A path-complete certificate is always the same three things:

1. a **labelled graph**, whose labels are the modes of the switched system;
2. a function `V_α` drawn from a **template** at each node;
3. one **inequality along each edge**.

The graph is **path-complete** when every switching sequence of the system is readable as a
path in it. That is the soundness condition — without it the inequalities certify nothing.

**What makes this package different from the tools that exist**
([SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl), the MATLAB
[JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)):
they treat the path-complete graph as an internal device for obtaining a
joint-spectral-radius bound. Here the graph is *the object of study* — something you build,
compare against another, order, and refine iteratively. Keep that framing when adding
features: a change that makes the graph less manipulable is working against the package.

---

## 2. The one architectural contract — read this before touching `src/`

Only the **edge inequality** changes between problems:

| Problem | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ γ⁻¹ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |
| Safety | the invariance condition |

The graph, the templates and the aggregation are identical. So the package has **two
independent axes**, not one type hierarchy:

- **template** (`src/templates/`) — what the node functions are;
- **problem** (`src/problems/`) — what the edge inequality says.

### The interfaces

A template is passed as an **instance**, never as a type. `QuadraticTemplate()` carries
nothing, but a template is not in general determined by its type: `PolyhedralTemplate` carries
one fixed matrix per node, and `::Type{T}` has nowhere to put it.

**A template supplies primitives; a problem chooses which to apply, and with what arguments.**
Neither axis names the other.

Every one of these is **public**. They are what a user implements, so none of them is
`_`-prefixed — a hidden extension point is a contradiction.

```julia
# --- Template axis (src/templates/). One file per template, answering all of it.
add_function_variables!(model, template, dim, node)  # -> the node function V_α
add_domination!(model, template, V_src, V_dst, map; scale = 1, margin = 0)
                                                     # scale·V_src(x) − V_dst(map·x) ≥ margin‖x‖ᵈ
add_nonnegativity!(model, template, V)               # V(x) ≥ 0
add_normalization!(model, template, V)               # excludes V ≡ 0
rate_exponent(template)                              # degree d: V(cx) = cᵈ V(x)
solution_value(template, V)                          # variables -> a callable node function
node_value(template, problem, V, x)                  # evaluate V_α; generic in the problem
check_dynamics(template, A)                          # is this template applicable at all?

# --- Problem axis (src/problems/). One file per problem, composing the above.
add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; rate = 1)

# --- Aggregation (src/aggregation.jl). Dispatches on the graph, so neither axis owns it.
#   complete → min over nodes;  co-complete → max;  otherwise min-of-max over the observer.
#   `common` is the literature's word (Philippe et al.) -- do not rename it to `aggregate`.
```

**Each problem defines its own certificate, in its own file.** `AbstractCertificate` fixes the
shared interface — `functions`, `status`, `is_feasible`, `problem`, `template`, `graph`, and
callability, where `certificate(x)` is the common function. What a problem actually certifies
is a **typed field** on its own type: `StabilityCertificate.rate`, `SafetyCertificate.margin`,
`OptimalControlCertificate.gains`. Not entries in a shared bag — a field is documented,
inferable and discoverable, and a new problem adds a type rather than inventing keys.

The six shared fields live once in `CertificateData`, which each certificate holds as `data`;
the accessors read it, so a certificate implements nothing to get them.

`add_domination!` is the load-bearing one. Quantifying an edge inequality over all `x` needs a
lifting into a cone, and that lifting is template-specific — which is why it cannot be written
once against a callable `V(x)`. But it is **problem-agnostic**: stability is this with
`scale = γᵈ`, safety is this on the homogeneous lift with `margin = ε`. So:

```julia
# The whole of stability's edge condition, for every template that exists or will:
add_edge_constraint!(model, ::StabilityProblem, template, V_src, V_dst, A, rate) =
    add_domination!(model, template, V_src, V_dst, A; scale = rate)
```

**A new template is one file in `src/templates/`. A new problem is one file in
`src/problems/`. Neither requires editing the other directory.** That is the contract, and
`grep -c '^function add_edge_constraint!' src/problems/*.jl` returning 1 everywhere is how you
check it still holds.

### How this was arrived at, so it is not undone

The contract once read *"a new template is two methods"*. Porting the two polyhedral templates
from Dionysos measured it instead. The first exposed four interface defects, all invisible while
the only templates were quadratic and copositive — both data-free, both degree 2:

| What it needed | Why the first two hid it |
| :-- | :-- |
| an instance, not a `::Type{T}` | quadratic and copositive carry no data; polyhedral carries a matrix per node |
| `add_nonnegativity!` dispatching on the *template* | it dispatched on the container, and `w` is a `Vector` exactly like `c` — silently the wrong constraint, with `w` in a denominator |
| `rate_exponent` | `γ²` was hard-coded, so `jsr_bound` returned `√JSR` for the degree-1 template |
| `solution_value` | `JuMP.value.(V)` works only if `V` is a bare container |

The second polyhedral template — facets as decision variables, a conic partition per node — then
needed **no interface change at all**, which is the evidence the two axes were right and only
their interface was shaped around a coincidence.

What remained was `add_edge_constraint!` scaling as templates × problems, and template-axis code
living in `problems/stability.jl` (all four `_add_normalization!` methods, three `_node_value`
methods, a copositive `isa` test). `add_domination!` removed the first; moving those methods to
their own template files removed the second.

**The one genuine exception is optimal control**, and it is documented in place rather than
smoothed over: its inequality is convex only after the substitution `S = P⁻¹`, `Y = KS`, so it
uses the template's variables as the *inverse* of the node function and cannot be written
against `V_src` and `V_dst` at all. A template wanting to support it must supply a second
primitive. One inhabitant is not yet a pattern, so none is introduced.

> **The failure mode this prevents.** The code this package grew from had three synthesis
> routines of 127, 171 and 200 lines that were largely the same program, differing only in
> the variable shape and two constraint forms. If you find yourself writing a fourth
> monolithic `compute_<something>` function, you have missed this section.

### Why a product, not an inheritance tree

The axes are orthogonal: quadratic-stability, quadratic-optimal-control and
polyhedral-stability all make sense. A single inheritance tree cannot express a product of two
axes — you would write `QuadraticStabilityCertificate`,
`QuadraticOptimalControlCertificate`, and so on. In Julia the product is expressed by
**parameters**; abstract types carry no fields, so a subtype inherits an interface, never data.

---

## 3. Repository map

What exists today. The package is young, so this is short.

**The two axes of §2 are the directory layout.** `templates/` and `problems/` have the same
shape on purpose — an `abstract.jl` holding the interface, then one file per inhabitant that
answers all of it. Adding a template or a problem is adding a file, and `ls src/` tells you the
architecture before you read a line.

```
src/
├── PathCompleteCertificates.jl   include order, grouped and commented
├── systems/                      the input to every problem, and runs of it
│   ├── switched.jl               switched linear systems, with and without an input
│   └── simulate.jl               sampling runs -- the substrate for `refute`
├── graphs/
│   ├── queries.jl                the adapter over HybridSystems.GraphAutomaton
│   ├── predicates.jl             is_path_complete (Def. II.1), is_complete / is_co_complete
│   ├── de_bruijn.jl              the De Bruijn family, primal and dual
│   └── observer.jl               the subset construction
├── templates/                    AXIS 1 — what the node functions are
│   ├── abstract.jl               AbstractTemplate and the primitives it must supply
│   ├── linear_copositive.jl
│   ├── quadratic.jl
│   ├── polyhedral.jl             symmetric 2n-face, fixed facets
│   └── conic_polyhedral.jl       free facets, plus the partition that linearises them
├── problems/                     AXIS 2 — what the edge inequality says
│   ├── abstract.jl               AbstractProblem, add_edge_constraint!, shared statuses
│   ├── stability.jl
│   ├── safety.jl
│   └── optimal_control.jl
└── aggregation.jl                `common` — the join; dispatches on the graph, so it
                                  belongs to neither axis
```

| Path | What it is |
| :--- | :--- |
| `ext/` | Optional interop, one extension per weak dependency |
| `test/` | Mirrors `src/` **including its subdirectories**. Entry point `test/runtests.jl`; every file is standalone-runnable |
| `docs/` | The manual, the examples and these developer docs |
| `docs/src/examples/` | Runnable scripts, **executed by the docs build** via Literate. Run one with `--project=docs`, which is where `Clarabel` and `Plots` live — never a dependency of the package or of the environment CI instantiates. There is no top-level `examples/`: it was folded in here so an example cannot go stale unnoticed |

Add a directory when there is something to put in it, not before.

Two placements that are deliberate rather than obvious:

- **The conic partition lives with its template, not under `graphs/`.** It partitions the
  *state space*, not the graph; it is indexed by node only because each node gets one. Nothing
  graph-shaped touches it. (The plan filed it under `graphs/` — that was wrong.)
- **`aggregation.jl` is top-level.** `common` reads all three of graph, template and problem,
  so filing it inside one axis would misrepresent it. §2's contract names three things; there
  are three homes.

Avoid `utils.jl` and `*_helper.jl`. Both existed here and both were junk drawers — name a file
for what is in it, and if nothing fits, that is the signal a concept is missing.

**The path-complete graph is a `HybridSystems.GraphAutomaton`** — the same type as the
system's own automaton. The package owns no graph type; `graph_helper.jl` adds the queries.
That keeps one vocabulary across the system and the certificate, and it is why `label` takes
the graph (`label(graph, edge)`): a `GraphTransition` carries its id, not its label.

> The cost, so it is not rediscovered as a surprise: `GraphAutomaton` does not subtype
> `Graphs.AbstractGraph`, so the ecosystem's algorithms do not come for free; label lookup
> reaches into its `Σ` field; and the queries are still linear scans. Accepted deliberately.
> **Because the two graphs are now the same type, nothing but the argument name stops
> `system.automaton` being passed where the certificate graph belongs** — so keep the
> arguments named `system`, `graph` and `reachability`, never `automaton`.

---

## 4. Conventions

**The authority is the [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/).**

- **Modules and types** CamelCase; **functions** snake_case; **constants** `UPPER_CASE`;
  **non-public** names `_`-prefixed.
- **Mutating functions end in `!`**.
- **Argument ordering** follows the documented order: *function argument, I/O stream, input
  being mutated, **type**, input not being mutated, key, value, …* — which is why
  `safety_certificate(QuadraticTemplate, graph, problem; optimizer)` takes the type first,
  the same shape as `parse(Int, s)` and `read(io, T)`.
- **No unnecessary static parameters.** `f(x::T) where {T <: Real}` becomes `f(x::Real)` when
  the parameter is unused.
- **No type piracy.** Never add `Base` methods to LazySets, JuMP or HybridSystems types — Aqua
  fails the build on it.
- **Prefer methods over field access.** Reach for `alphabet(g)`, not `g.alphabet`: the graph
  backing store is expected to change.
- **Predicates** are `is_*`. **No `get_` / `compute_` / `build_` / `generate_` prefixes** — the
  noun *is* the function.
- **No acronyms in exported names.** No `PCLF`, `CLF`, `MLF`.
- **One word per concept.** It is `alphabet`, never `modes` or `labels`.
- **Node functions are callable**: `V(x)`, not `piece_value(V, x)`.
- **Never hard-code `Float64` in a signature.** Take `Real` and parametrise on the number
  type — a certificate sometimes has to be exact (`Rational`, `BigFloat`) rather than numerical.

---

## 5. Gotchas

**Lift admissibility is template-dependent, and getting it wrong fails silently.**

Debauche, Della Rossa & Jungers showed that whether a lift may be applied depends on the
*analytical properties of the template*, not on the graph alone. A refinement loop that applies
a lift without checking will happily produce a certificate — one that certifies nothing.

So admissibility is answered through **properties**, never by dispatching on the concrete
template type (which would need one method per (lift, template) pair — *n × m*, the explosion
§2 exists to avoid):

```julia
closed_under_max(::Type{T})::Bool
closed_under_min(::Type{T})::Bool
closed_under_linear_image(::Type{T})::Bool

is_admissible(lift, ::Type{T})  # written ONCE, against the properties
```

**`refute` and `certify` are not the same thing.** `refute` samples looking for a violation:
it is a cheap way to learn you are wrong, and finding nothing proves nothing. `certify` solves
for the guarantee. Never present one as the other — conflating them is how unsound results
ship.

**Three predicates, and they are not the same thing.** Philippe, Athanasopoulos, Angeli &
Jungers, *On Path-Complete Lyapunov Functions*, is the authority:

| Predicate | Paper | Meaning |
| :-- | :-- | :-- |
| `is_path_complete` | Def. II.1 | **every** finite switching sequence is readable as a path |
| `is_complete` | Def. III.2 | every node has an *outgoing* edge for every mode |
| `is_co_complete` | Def. III.2 | every node has an *incoming* edge for every mode |

`is_complete` and `is_co_complete` are **sufficient, not necessary**. A graph can read every
word without every node reading every letter, so never use them to answer "is this a valid
certificate" — that question is `is_path_complete`, decided by the subset construction (the
graph is path-complete iff the subset construction from *all* nodes never reaches ∅).

What each one licenses (Cor. III.3, Thm III.8) is why both survive: complete → aggregate with
`min`, co-complete → `max`, general path-complete → `min` of `max` over the observer graph.
`common` dispatches on exactly that.

Neither is graph-theoretic completeness, where every pair of vertices is adjacent.

**Path-completeness is relative to an alphabet, and the default is the weaker question.**
`is_path_complete(graph)` asks about the labels the graph *happens to use*, so a graph that
never mentions a mode passes trivially — and then certifies nothing about that mode. It once
returned a JSR bound of 0.906 for a system whose JSR is at least 3. Always pass the system's
alphabet when the question is about a certificate: `is_path_complete(graph, 1:n_modes)`.
Every problem's data check calls `_check_path_complete(graph, length(A))`; add the call when
you add a problem.

---

## 6. Commands

```
# Narrowest scope first — every test file is standalone-runnable
julia --project=test test/graphs/predicates.jl

# Fast subset: skips :slow suites (the SDP/LP-heavy synthesis tests)
julia --project -e 'using Pkg; Pkg.test(; test_args = ["--fast"])'

# Full gate, before committing
julia --project -e 'using Pkg; Pkg.test()'

# Format — REQUIRED before every commit, CI fails on any diff
julia -e 'using JuliaFormatter; format(".")'

# Docs. The examples under docs/src/examples/ are EXECUTED by this build, so it
# solves a handful of SDPs and draws two figures -- a few minutes, not seconds.
julia --project=docs docs/make.jl

# Docs without running the examples, for fast iteration on prose
PCC_SKIP_LITERATE=true julia --project=docs docs/make.jl
```

New test files go in the `TEST_FILES` list in `test/runtests.jl` (tag a slow suite `:slow`).

`makedocs` runs with `checkdocs = :all`, but the package **exports nothing deliberately**, so
that setting has no symbol list to work from and checks nothing for coverage. The real gate is
`test/docstrings.jl`, which walks every non-underscore name reachable as `PCC.name`. What
`checkdocs` still catches is a docstring missing from the manual — every one must land in an
`@autodocs` block under `docs/src/reference/`.

### Don't relaunch Julia for every check

A cold `julia` costs ~30 s of startup and precompilation, and `Pkg.test()` adds Aqua's
persistent-task probe (~50 s) on top. Iterate in **one long-lived session** instead: the four
test files together take 80 s warm against roughly five minutes of cold starts.

```julia
julia --project=test          # once, and leave it open
using Revise                  # picks up edits to src/ without a restart
include("test/safety.jl")     # rerun after each edit; ~8 s instead of ~3 min
```

In VS Code that is the integrated Julia REPL (`Alt-J Alt-O`); an agent without a terminal it can
keep open gets the same effect from a background `julia` process that polls a file for code and
writes the output to a log — same session, same warm caches, one message per command.

Run the cold `Pkg.test()` **once** at the end, as the gate. It is what CI runs; it is not an
iteration loop.

**Trap:** `Manifest.toml` is gitignored, so a branch that adds a dependency leaves yours stale
and `Pkg.test()` fails on `"X is a direct dependency, but does not appear in the manifest"`
before running a single test. Fix with `rm Manifest.toml` then `Pkg.resolve()` — in the
environment that failed (root, `test/` or `docs/`), not always the root one.

---

## 7. Git workflow

Never commit to `master`; branch per change; format before committing; open a PR.

**Commit message format:** `[ACTION] module: description` — lowercase, no trailing period,
≤ 60 chars. Actions: `ADD`, `IMP`, `FIX`, `REF`, `REM`, `MOV`, `REV`. Module is the touched
subsystem (`graphs`, `templates`, `problems`, `systems`, `aggregation`, `test`, `docs`,
`meta`), or `examples` for a change confined to `docs/src/examples/`.

Do **not** add a `Co-Authored-By` line.

---

## 8. Two traps measured, not guessed

**Path-completeness is PSPACE-complete to decide, so it is checked once and can be waived.** It is NFA universality, and
`is_path_complete` is the subset construction — exponential in `|V|` in the worst case. It is
usable here because the graphs are not worst cases (a De Bruijn graph visits about `2|V|`
subsets, not `2^|V|`) and because complete / co-complete short-circuit it. Refinement tests
many candidate graphs with this predicate, so measure here first if a loop gets slow.

**Index adjacency before scanning it.** `is_complete` used to call `outgoing_edges(graph, node,
letter)` per pair, each a full scan of the edge list — `O(|V|·|Σ|·|E|)`. On `M = 4, k = 4` that
was 46 ms, **50× slower than the PSPACE-complete predicate it was supposed to be a cheap
substitute for**. Building the index once made it 0.1 ms. The graph queries in
`graphs/queries.jl` are still linear scans; if any of them lands in a hot loop, do the same.

Two consequences of that cost, both already in the code:

- **Check once per solve, not once per model.** `jsr_bound` used to validate, then build a model
  per bisection step, each rebuild revalidating — running the PSPACE-complete test a dozen times
  on a graph that cannot have changed. It now checks once and passes `path_complete = false`
  inward.
- **`path_complete = false` on every entry point** waives the test and *asserts* the property,
  for a caller with a large graph or one whose construction already guarantees it — a lift of a
  path-complete graph, say. It is not the default and must not become one: the failure it guards
  against is silent and unsound, and a rare performance cliff is the better risk. De Bruijn
  graphs are cheap here (≈ 2|V| subsets), but nothing stops a user passing an arbitrary graph.
