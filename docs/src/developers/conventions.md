# Coding conventions

The authoritative version of what `CLAUDE.md` summarises. Read §1 before writing any code in
`src/` — the rest is house style, but §1 is the thing the package is built on.

## 1. The architectural contract: two axes, not a hierarchy

A path-complete certificate is always the same three things: a **labelled graph**, a function
`V_α` drawn from a **template** at each node, and one **inequality along each edge**.

Between problems, only the edge inequality changes:

| Problem | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ γ⁻ᵈ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |
| Safety | the invariance condition |

The graph, the templates and the aggregation are identical throughout. So the package has **two
independent axes**:

- **template** (`src/templates/`) — what the node functions are;
- **problem** (`src/problems/`) — what the edge inequality says.

### The interfaces

A template supplies primitives; a problem chooses which to apply, and with what arguments. Neither
axis names the other. Every one of these is public — a user implements them, so none is
`_`-prefixed.

```julia
# --- Template axis (src/templates/). One file per template, answering all of it.
rate_exponent(template)                              # degree d: V(cx) = cᵈ V(x)
add_function_variables!(model, template, dim, node)  # -> the node function V_α
add_nonnegativity!(model, template, V)               # V(x) ≥ 0
add_normalization!(model, template, V)               # excludes V ≡ 0
add_domination!(model, template, V_src, V_dst, map; scale = 1, margin = 0)
                                  # scale·V_src(x) − V_dst(map·x) ≥ margin‖x‖ᵈ
solution_value(template, V)                          # variables -> a callable node function
check_dynamics(template, A)                          # is this template applicable at all?

# --- Problem axis (src/problems/). One file per problem, composing the above.
add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; rate = 1)
node_value(template, problem, V, x)                  # evaluate V_α; generic in the problem

# --- Aggregation (src/aggregation.jl). Dispatches on the graph, so neither axis owns it.
common(template, graph, problem, Vs, x)
#   complete → min over nodes; co-complete → max; otherwise min-of-max over the observer.
```

**A new template is one file in `src/templates/`. A new problem is one file in `src/problems/`.
Neither requires editing the other directory.** That is the contract, and counting
`add_edge_constraint!` definitions per file in `src/problems/` — one everywhere — is how you check
it still holds.

`add_domination!` is the load-bearing one. Quantifying an edge inequality over all `x` needs a
lifting into a cone, and that lifting is template-specific, which is why it cannot be written once
against a callable `V(x)`. But it is problem-agnostic, so the whole of stability's edge condition,
for every template that exists or will, is one call:

```julia
add_edge_constraint!(model, ::StabilityProblem, template, V_src, V_dst, A; rate = 1) =
    add_domination!(model, template, V_src, V_dst, A; scale = rate)
```

!!! warning "A template is an instance, never a type"
    `QuadraticTemplate()` carries nothing, but a template is not in general determined by its
    type: `PolyhedralTemplate` carries one fixed matrix per node, and `::Type{T}` has nowhere to
    put it. Pass `QuadraticTemplate()`, not `QuadraticTemplate`.

The one genuine exception is **optimal control**: its inequality is convex only after the
substitution `S = P⁻¹`, `Y = KS`, so it uses the template variables as the *inverse* of the node
function and cannot be written against `V_src` and `V_dst` at all. One inhabitant is not yet a
pattern, so no second primitive is introduced for it.

!!! warning "The failure mode this prevents"
    The code this package grew from had three synthesis routines of 127, 171 and 200 lines that
    were largely the same program — same model construction, same bisection, same controls —
    differing only in the variable shape and two constraint forms. If you find yourself writing a
    fourth monolithic `compute_<something>` function, you have missed this section.

### Why a product rather than an inheritance tree

The axes are orthogonal: quadratic-stability, quadratic-optimal-control and polyhedral-stability
all make sense. A single inheritance tree cannot express a product of two axes — you would end up
writing `QuadraticStabilityCertificate`, `QuadraticOptimalControlCertificate`,
`PolyhedralStabilityCertificate`, which is exactly the explosion the abstraction exists to avoid.

In Julia the product is expressed by **parameters**. Abstract types carry no fields and inheritance
is single, so a subtype inherits an interface, never data.

### Each problem owns its certificate

`AbstractCertificate` fixes the shared interface — `functions`, `status`, `is_feasible`, `problem`,
`template`, `graph`, and callability, where `certificate(x)` is the common function. What a problem
actually certifies is a **typed field** on its own type: `StabilityCertificate.rate`,
`SafetyCertificate.margin`, `OptimalControlCertificate.gains`. Not entries in a shared bag — a
field is documented, inferable and discoverable, and a new problem adds a type rather than
inventing keys.

The six shared fields live once in `CertificateData`, which each certificate holds as `data`, so a
certificate implements nothing to get the accessors.

### Template is not the same thing as the fitted function

The literature separates the *family* `𝒯` from the fitted member `V_α ∈ 𝒯`. So does the package:
`AbstractTemplate` is the family, and `solution_value(template, V)` turns solved JuMP variables
into the fitted, callable member. Do not collapse them — that conflation is how `EllipsoidalPiece`,
in the code this package grew from, ended up named after a level set rather than after the function
that induces it.

## 2. Naming

- **Modules and types** CamelCase; **functions** snake_case; **constants** `UPPER_CASE`;
  **non-public** names `_`-prefixed.
- **Mutating functions end in `!`**.
- **Predicates** are `is_*`.
- **No `get_` / `compute_` / `build_` / `generate_` prefixes.** The noun *is* the function:
  `jsr_bound(graph, system)`, not `compute_jsr_bound`. `Base` does this throughout — `length`,
  `size`, `eltype`, `parent`.
- **No acronyms in exported names.** No `PCLF`, `CLF`, `MLF`.
- **One word per concept.** It is `alphabet`, never `modes` or `labels`. And it is `common` — the
  term Philippe et al. use for the aggregated function — never `aggregate`.
- **Node functions are callable**: `V(x)`, not `piece_value(V, x)`.

The reference throughout is the
[Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/).

## 3. Interfaces and types

- **Argument ordering** follows the documented Julia order: *function argument, I/O stream, input
  being mutated, **type**, input not being mutated, key, value, …*. This is why
  `safety_certificate(QuadraticTemplate(), graph, problem; optimizer)` takes the template first —
  the same shape as `parse(Int, s)` and `read(io, T)`.
- **No unnecessary static parameters.** `f(x::T) where {T <: Real}` becomes `f(x::Real)` when the
  parameter is never used.
- **No type piracy.** Never add `Base` methods to LazySets, JuMP or HybridSystems types. Aqua fails
  the build on it, and it breaks unrelated code at a distance.
- **Prefer methods over field access.** Use `alphabet(g)`, not `g.alphabet`. The graph backing store
  is expected to change, and accessors are what make that a non-event.
- **Never hard-code `Float64` in a signature.** Take `Real` and parametrise on the number type. A
  certificate sometimes has to be *exact* — `Rational`, `BigFloat` — rather than numerical, and a
  `::Float64` annotation shuts that door for no benefit.

## 4. Three predicates, and they are not the same thing

Philippe, Athanasopoulos, Angeli & Jungers, *On Path-Complete Lyapunov Functions*, is the
authority:

| Predicate | Paper | Meaning |
| :-- | :-- | :-- |
| `is_path_complete` | Def. II.1 | **every** finite switching sequence is readable as a path |
| `is_complete` | Def. III.2 | every node has an *outgoing* edge for every mode |
| `is_co_complete` | Def. III.2 | every node has an *incoming* edge for every mode |

`is_complete` and `is_co_complete` are **sufficient, not necessary**. A graph can read every word
without every node reading every letter, so never use them to answer "is this a valid certificate"
— that question is `is_path_complete`, decided by the subset construction. What each one licenses
(Cor. III.3, Thm III.8) is why both survive, and is exactly what `common` dispatches on.

None of the three is graph-theoretic completeness, where every pair of vertices is adjacent.

Path-completeness is also **relative to an alphabet**, and the bare `is_path_complete(graph)` asks
the weaker question — about the labels the graph happens to use. A graph that never mentions a mode
passes it trivially and then certifies nothing about that mode; it once returned a bound of `0.906`
for a system whose joint spectral radius is at least 3. Pass the alphabet of the system.

Deciding it is PSPACE-complete, so it is checked once per solve rather than once per model, and
`path_complete = false` on an entry point waives the test and *asserts* the property. That is for a
caller whose graph is large or whose construction already guarantees it. It must not become the
default: the failure it guards against is silent and unsound.

## 5. Rules for work that is not here yet

Two designs are settled but unimplemented. They are recorded so that the first implementation does
not have to rediscover them.

**Lift admissibility depends on the template.** Debauche, Della Rossa and Jungers showed that
whether a lift may be applied depends on the *analytical properties of the template*, not on the
graph alone. A refinement loop that applies a lift without checking will happily produce a
certificate — one that certifies nothing. So admissibility must be answered through **properties**,
never by dispatching on the concrete template type, which would need one method per
(lift, template) pair: the *n × m* explosion §1 exists to avoid.

```julia
closed_under_max(::Type{T})::Bool
closed_under_min(::Type{T})::Bool
closed_under_linear_image(::Type{T})::Bool

is_admissible(lift, ::Type{T})  # written ONCE, against the properties
```

This is the most expensive mistake available here, because it fails silently.

**`refute` will not be `certify`.** A refutation routine samples looking for a violation: it is a
cheap way to learn you are wrong, and finding nothing proves nothing. `certify` solves for the
guarantee. When refutation lands, keep both visible in the API and never present one as the other —
conflating them is how unsound results ship.

## 6. Tests, formatting, docs

- Every test file is standalone-runnable and wired into `TEST_FILES` in `test/runtests.jl`.
- Format before every commit; CI fails on any diff.
- **Every name reachable as `PathCompleteCertificates.name` needs a docstring.** The package
  exports nothing deliberately, which means Documenter's `checkdocs = :all` has no symbol list to
  work from and checks nothing — eight docstrings written as `raw"""`, which never attach, once
  went missing exactly that way. `test/docstrings.jl` is the real gate: it walks every
  non-underscore reachable name and fails on any that is undocumented.
