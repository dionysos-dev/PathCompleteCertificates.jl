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

**What makes this package different from the tools that exist** (SwitchOnSafety.jl, the
MATLAB JSR Toolbox): they treat the path-complete graph as an internal device for obtaining a
joint-spectral-radius bound. Here the graph is *the object of study* — something you build,
compare against another, order, and refine iteratively. Keep that framing when adding
features: a change that makes the graph less manipulable is working against the package.

---

## 2. The one architectural contract — read this before touching `src/`

Only the **edge inequality** changes between objectives:

| Objective | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ γ⁻¹ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |
| Safety | the invariance condition |

The graph, the templates and the aggregation are identical. So the package has **two
independent axes**, not one type hierarchy:

- **template** (`src/templates/`) — what the node functions are;
- **objective** (`src/objectives/`) — what the edge inequality says.

### The interfaces

```julia
# Template axis — two methods per template.
add_function_variables!(model, ::Type{T}, dim, node)  # -> a V_α of JuMP variables
add_nonnegativity!(model, V)                          # V(x) ≥ 0

# Objective axis — one method per objective.
add_edge_constraint!(model, objective, V_src, V_dst, dynamics, mode)

# Aggregation — a trait on the graph, not a method per objective.
aggregate(::Complete, Vs)      # min over nodes
aggregate(::CoComplete, Vs)    # max over nodes
aggregate(::Reachability, Vs)  # min over sets, max within
```

**A new objective is one method. A new template is two. Their combination costs nothing.**

That sentence is the contract. Every design decision is answerable to it.

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

What exists today — the package is young, so this is short:

| Path | What it is |
| :--- | :--- |
| `src/graph.jl` | The labelled digraph and the path-completeness predicates |
| `src/systems.jl` | Switched linear systems, with and without a control input |
| `ext/` | Optional interop, one extension per weak dependency |
| `test/` | Mirrors `src/`. Entry point `test/runtests.jl`; each file is standalone-runnable |
| `examples/` | Runnable scripts, run with `--project=test` |
| `docs/` | The manual and these developer docs |

Coming, per the two axes of §2: `templates/` (what the node functions are),
`objectives/` (what the edge inequality says), and the synthesis driver over them.
Add a directory when there is something to put in it, not before.

---

## 4. Conventions

**The authority is the [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/).**

- **Modules and types** CamelCase; **functions** snake_case; **constants** `UPPER_CASE`;
  **non-public** names `_`-prefixed.
- **Mutating functions end in `!`**.
- **Argument ordering** follows the documented order: *function argument, I/O stream, input
  being mutated, **type**, input not being mutated, key, value, …* — which is why
  `synthesize(QuadraticTemplate, graph, system, objective; optimizer)` takes the type first,
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

**Path-completeness is not graph completeness.** A "complete graph" in graph theory has every
pair of vertices adjacent. That is a different property. The predicate is `is_path_complete`.

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

# Docs
julia --project=docs docs/make.jl
```

New test files go in the `TEST_FILES` list in `test/runtests.jl` (tag a slow suite `:slow`).

`makedocs` runs with `checkdocs = :all`: **every exported symbol needs a docstring** or the
build fails. That is deliberate — the docs carry what the six-page paper cannot.

---

## 7. Git workflow

Never commit to `master`; branch per change; format before committing; open a PR.

**Commit message format:** `[ACTION] module: description` — lowercase, no trailing period,
≤ 60 chars. Actions: `ADD`, `IMP`, `FIX`, `REF`, `REM`, `MOV`, `REV`. Module is the touched
subsystem (`graphs`, `lifts`, `templates`, `objectives`, `synthesis`, `verification`, `test`,
`docs`, `meta`).

Do **not** add a `Co-Authored-By` line.
