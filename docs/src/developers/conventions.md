# Coding conventions

The authoritative version of what `CLAUDE.md` summarises. Read §1 before writing any code in
`src/` — the rest is house style, but §1 is the thing the package is built on.

## 1. The architectural contract: two axes, not a hierarchy

A path-complete certificate is always the same three things: a **labelled graph**, a function
`V_α` drawn from a **template** at each node, and one **inequality along each edge**.

Between objectives, only the edge inequality changes:

| Objective | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ γ⁻¹ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |
| Safety | the invariance condition |

The graph, the templates and the aggregation are identical throughout. So the package has **two
independent axes**:

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

That sentence is the contract, and every design decision is answerable to it.

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

### Template is not the same thing as the fitted function

The literature separates the *family* `𝒯` from the fitted member `V_α ∈ 𝒯`. So does the package:
`AbstractTemplate` is the family, `AbstractNodeFunction` the fitted function. Do not collapse them —
that conflation is how `EllipsoidalPiece` ended up named after a level set rather than after the
function that induces it.

## 2. Naming

- **Modules and types** CamelCase; **functions** snake_case; **constants** `UPPER_CASE`;
  **non-public** names `_`-prefixed.
- **Mutating functions end in `!`**.
- **Predicates** are `is_*`.
- **No `get_` / `compute_` / `build_` / `generate_` prefixes.** The noun *is* the function:
  `sublevel_set(p, γ)`, not `get_sublevel_set`. `Base` does this throughout — `length`, `size`,
  `eltype`, `parent`.
- **No acronyms in exported names.** No `PCLF`, `CLF`, `MLF`.
- **One word per concept.** It is `alphabet`, never `modes` or `labels`.
- **Node functions are callable**: `V(x)`, not `piece_value(V, x)`.

!!! note "This is Julia style, not Dionysos house style"
    Dionysos.jl prescribes `get_<noun>` / `get_<noun>_by_<key>` accessors. That convention is
    internal to Dionysos and is not the wider Julia one. This package follows the
    [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/). If the two ever need
    to meet, Dionysos re-exports under whatever names it likes — a thin alias layer is cheap, and it
    is the right place to absorb the difference.

## 3. Interfaces and types

- **Argument ordering** follows the documented Julia order: *function argument, I/O stream, input
  being mutated, **type**, input not being mutated, key, value, …*. This is why
  `synthesize(QuadraticTemplate, graph, system, objective; optimizer)` takes the type first — the
  same shape as `parse(Int, s)` and `read(io, T)`.
- **No unnecessary static parameters.** `f(x::T) where {T <: Real}` becomes `f(x::Real)` when the
  parameter is never used.
- **No type piracy.** Never add `Base` methods to LazySets, JuMP or HybridSystems types. Aqua fails
  the build on it, and it breaks unrelated code at a distance.
- **Prefer methods over field access.** Use `alphabet(g)`, not `g.alphabet`. The graph backing store
  is expected to change, and accessors are what make that a non-event.
- **Never hard-code `Float64` in a signature.** Take `Real` and parametrise on the number type. A
  certificate sometimes has to be *exact* — `Rational`, `BigFloat` — rather than numerical, and a
  `::Float64` annotation shuts that door for no benefit.

## 4. Two distinctions worth keeping sharp

**`refute` is not `certify`.** `refute` samples looking for a violation: it is a cheap way to learn
you are wrong, and finding nothing proves nothing. `certify` solves for the guarantee. Keep both
visible in the API and never present one as the other — conflating them is how unsound results
ship.

**Path-completeness is not graph completeness.** A "complete graph" in graph theory has every pair
of vertices adjacent; that is a different property entirely. The predicate is `is_path_complete`,
and the longer name is the point.

## 5. Lift admissibility depends on the template

Debauche, Della Rossa and Jungers showed that whether a lift may be applied depends on the
*analytical properties of the template*, not on the graph alone. A refinement loop that applies a
lift without checking will happily produce a certificate — one that certifies nothing.

So admissibility is answered through **properties**, never by dispatching on the concrete template
type. Dispatching would need one method per (lift, template) pair, which is the *n × m* explosion §1
exists to avoid:

```julia
closed_under_max(::Type{T})::Bool
closed_under_min(::Type{T})::Bool
closed_under_linear_image(::Type{T})::Bool

is_admissible(lift, ::Type{T})  # written ONCE, against the properties
```

This is the package's most expensive mistake to make, because it fails silently.

## 6. Tests, formatting, docs

- Every test file is standalone-runnable and wired into `TEST_FILES` in `test/runtests.jl`.
- Format before every commit; CI fails on any diff.
- Every exported symbol needs a docstring — `checkdocs = :all`.
