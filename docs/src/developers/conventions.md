# Coding conventions

The long version of what `CLAUDE.md` summarises: the rules, and the history and measurements
behind them. Read §1 before writing any code in `src/`.

## 1. The architectural contract: two axes, not a hierarchy

A path-complete certificate is always the same three things: a **labelled graph**, a function
`V_s` drawn from a **template** at each node, and one **inequality along each edge**.

Between problems, only the edge inequality changes:

| Problem | Edge inequality on `(s, d, i)` |
| :-- | :-- |
| Stability | `V_s(x) ≥ γ⁻ᵈ V_d(A_i x)` |
| Optimal control | `V_s(x) ≥ c(x) + V_d(f_i(x))` |
| Safety | the invariance condition |

The graph, the templates and the common function are identical throughout. So the package has
**two independent axes**:

- **template** (`src/templates/`) — what the node functions are;
- **problem** (`src/problems/`) — what the edge inequality says.

### The interfaces

A template supplies primitives; a problem chooses which to apply, and with what arguments.
Neither axis names the other. Every one of these is public — a user implements them, so none is
`_`-prefixed.

```julia
# --- Template axis (src/templates/catalogue/). One file per template, answering all of it.
homogeneity_degree(template)                         # degree d: V(cx) = cᵈ V(x)
add_function_variables!(model, template, dim, node)  # -> the node function V_s
add_nonnegativity!(model, template, V)               # V(x) ≥ 0
add_normalization!(model, template, V)               # excludes V ≡ 0
add_domination!(model, template, V_src, V_dst, map; scale = 1, margin = 0)
                                  # scale·V_src(x) − V_dst(map·x) ≥ margin‖x‖ᵈ
domination_slack(template, V_src, V_dst, map; scale = 1)  # the same, read off a solution
solution_value(template, V)                          # variables -> a callable node function
check_dynamics(template, A)                          # is this template applicable at all?
is_closed_under(template, ::Operation, system)       # default false; composition reads the system
reindex(template, origins)                           # default identity; per-node data follows a graph
has_dual(template), dual(template), dual(template, V)

# --- Problem axis (src/problems/catalogue/). One file per problem, composing the above.
add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; rate = 1)
node_value(template, problem, V, x)                  # evaluate V_s; generic in the problem
optimization_model(template, graph, problem; optimizer, ...)
certify(template, graph, problem; optimizer, ...)
best_certificate(template, graph, problem; optimizer, kwargs...)   # default certify; stability: jsr_bound
objective(certificate)                                              # smaller is better
optimality_gap(certificate; kwargs...)                              # default Inf; stability: the bracket and Theorem 4
edge_slacks(certificate)                                            # one method per problem, through domination_slack

# --- The common function (src/common.jl). Dispatches on the graph, so neither axis owns it.
common(template, graph, problem, Vs, x)
#   complete → min over nodes; co-complete → max; otherwise min-of-max over the observer.
```

**A new template is one file in `src/templates/catalogue/`. A new problem is one file in
`src/problems/catalogue/`. Neither requires editing the other directory.** That is the contract,
and counting `add_edge_constraint!` definitions per file in `src/problems/catalogue/` — one
everywhere — is how you check it still holds. Every directory with an interface has the same
shape: `abstract.jl` and the other interface files at the top, one file per inhabitant under
`catalogue/`, named after the type without the directory's suffix.

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

### How this was arrived at, so it is not undone

The contract once read *"a new template is two methods"*. Porting the two polyhedral templates
from Dionysos measured it instead. The first exposed four interface defects, all invisible while
the only templates were quadratic and copositive — both data-free, both degree 2:

| What it needed | Why the first two hid it |
| :-- | :-- |
| an instance, not a `::Type{T}` | quadratic and copositive carry no data; polyhedral carries a matrix per node |
| `add_nonnegativity!` dispatching on the *template* | it dispatched on the container, and `w` is a `Vector` exactly like `c` — silently the wrong constraint, with `w` in a denominator |
| `homogeneity_degree` | `γ²` was hard-coded, so `jsr_bound` returned `√JSR` for the degree-1 template |
| `solution_value` | `JuMP.value.(V)` works only if `V` is a bare container |

The second polyhedral template — facets as decision variables, a conic partition per node — then
needed **no interface change at all**, which is the evidence the two axes were right and only
their interface was shaped around a coincidence. What remained was `add_edge_constraint!` scaling
as templates × problems, and template-axis code living in the stability file; `add_domination!`
removed the first, moving those methods to their own template files removed the second.

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
inventing keys. The six shared fields live once in `CertificateData`, which each certificate holds
as `data`, so a certificate implements nothing to get the accessors.

### Template is not the same thing as the fitted function

The literature separates the *family* from the fitted member `V_s` in it. So does the package:
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
  `jsr_bound(template, graph, problem)`, not `compute_jsr_bound`. `Base` does this throughout —
  `length`, `size`, `eltype`, `parent`.
- **No acronyms in public names.** No `PCLF`, `CLF`, `MLF`.
- **One word per concept, and the papers' word when one exists.** It is `alphabet`, never `modes`
  or `labels`; `common`, the word of Philippe et al. for the single function the node functions
  combine into, never `aggregate`; `simulation`, never `witness`; `valid`, never `admissible`;
  `tight`, the word of Ninite & Jungers; `common_graph`, the common Lyapunov function graph
  `G_0`; the primal De Bruijn graph and its `dual`.
- **Node functions are callable**: `V(x)`, not `piece_value(V, x)`.
- **No `Base.show` methods.**

The reference throughout is the
[Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/).

## 3. Interfaces and types

- **Argument ordering** follows the documented Julia order: *function argument, I/O stream, input
  being mutated, **type**, input not being mutated, key, value, …*. This is why
  `certify(QuadraticTemplate(), graph, problem; optimizer)` takes the template first —
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

## 4. The graph layer

**The path-complete graph is a `HybridSystems.GraphAutomaton`**, the same type as the system's
own automaton. The package owns no graph type; `graphs/queries.jl` adds the queries. That keeps
one vocabulary across the system and the certificate, and it is why `label` takes the graph
(`label(graph, edge)`): a `GraphTransition` carries its id, not its label. The cost, so it is not
rediscovered: `GraphAutomaton` does not subtype `Graphs.AbstractGraph`, so the ecosystem's
algorithms do not come for free, and the queries are linear scans. Because the two graphs are
the same type, nothing but the argument name stops `system.automaton` being passed where the
certificate graph belongs — keep the arguments named `system` and `graph`, never `automaton`.

**The adapter invariant.** `graphs/queries.jl` is the one file that touches HybridSystems' graph
internals: `grep -rn "_HS\.\(GraphAutomaton\|add_transition!\|Σ\)" src | grep -v queries` is
empty. It is what let words in without the rest of the package noticing, and what lets the
backing store change in one file. Build graphs with `empty_graph(n)`, `WordGraph(n)`, or
`_empty_like(graph, n)` for one of the same kind as `graph`.

**Keep the graph constructors type-stable.** A constructor returning either a `GraphAutomaton` or
a `WordGraph` by keyword made every construction routed through it infer as a union of a mutable
and an immutable struct. On Julia 1.12.5 a closure that called `certify` through a non-const
global on such a graph and then read the result crashed with an access violation — not an error,
a crash. That is why the kind of graph is chosen by dispatch, never by a keyword, and why
`Base.return_types(de_bruijn, (Int, Int))` must stay a single concrete type.

**Three predicates, and they are not the same thing.** Philippe, Athanasopoulos, Angeli &
Jungers, *On Path-Complete Lyapunov Functions*, is the authority:

| Predicate | Paper | Meaning |
| :-- | :-- | :-- |
| `is_path_complete` | Def. II.1 | **every** finite switching sequence is readable as a path |
| `is_complete` | Def. III.2 | every node has an *outgoing* edge for every mode |
| `is_co_complete` | Def. III.2 | every node has an *incoming* edge for every mode |

`is_complete` and `is_co_complete` are **sufficient, not necessary**. A graph can read every word
without every node reading every letter, so never use them to answer "is this a valid certificate"
— that question is `is_path_complete`, decided by the subset construction. What each one licenses
(Cor. III.3, Thm III.8) is why both survive, and is exactly what `common` dispatches on. None of
the three is graph-theoretic completeness, where every pair of vertices is adjacent.

Path-completeness is also **relative to an alphabet**, and the bare `is_path_complete(graph)` asks
the weaker question, about the labels the graph happens to use. A graph that never mentions a mode
passes it trivially and then certifies nothing about that mode; it once returned a bound of `0.906`
for a system whose joint spectral radius is at least 3. Pass the alphabet of the system; every
problem's data check does.

**Words on edges are a stability feature.** A `WordGraph` edge reads several modes and imposes
one inequality on their product; it bounds the growth rate and says nothing about the states
inside the word. Safety, optimal control and `common` require a letter graph and name
`expanded_form` in their error.

**Two traps measured, not guessed.** Path-completeness is PSPACE-complete to decide: it is NFA
universality, and `is_path_complete` is the subset construction, exponential in the worst case.
It is usable because the graphs are not worst cases (a De Bruijn graph visits about `2|V|`
subsets) and because complete and co-complete short-circuit it; it is checked once per solve, not
once per model, and `path_complete = false` on an entry point waives it for a caller whose
construction guarantees it — never the default, since the failure it guards is silent. And index
adjacency before scanning it: `is_complete` once called the star query per node and letter, a
full scan of the edge list each time, `O(|V|·|Σ|·|E|)`, 46 ms on `M = 4, k = 4` and fifty times
slower than the PSPACE-complete predicate it was meant to short-circuit; the indices
`_successors` and `_predecessors`, built once, made it 0.1 ms.

## 5. Lifts, refinements, and the two things that are not axes

Both transform a path-complete graph into a path-complete graph, which is the literature's
definition of a lift (Debauche, Della Rossa and Jungers, Def. 5). They are kept apart by
purpose. **A lift compares graphs**: it is the lift of an operation, its nodes stand for
combinations of the original nodes, and when the lifted `G` simulates `H` then `G ≤_V H` for every
template closed under that operation. It never improves a graph, except the composition lift.
**A refinement improves a graph**: it is valid for every template by construction, the `origins`
being the simulation that proves it (Def. 6(c)), and `refine` applies one where a certificate is
tight.

Validity of a lift is answered through **properties**, never by dispatching on the concrete
template type, which would need one method per (lift, template) pair: the *n × m* explosion §1
exists to avoid. One override exists, `is_valid(::MinLift, ::LinearCopositiveTemplate, system)`,
because the literature proves validity there without closure (Debauche, Thm. 7.43); add another
only with a theorem to cite. `is_valid` also reads the dual side (Prop. 7.5), so a closure
declared on either of a dual pair of templates serves both; `dual(certificate)` is the
constructive form of the same duality (Lemma 6.25), and `test/problems/dual.jl` asserts it on
every lift and refinement.

```julia
# --- src/operations.jl: the vocabulary both axes and the lifts share.
Addition(), Maximum(), Minimum(), Composition(), InverseComposition()   # <: Operation; `dual` pairs them

# --- A lift (src/lifts/catalogue/): two methods to implement, two inherited.
lift(L, graph)                                   # returns a Lifted: the graph and what every node stands for
requirements(L)                                  # a tuple of operations; () for the identity lift
simulation(L, G, H; optimizer)                   # the simulation of H by lift(L, G); overridden where cheaper
is_valid(L, template, system)                    # written ONCE against the two; one cited override exists
dual(L)                                          # DualLift: conjugation by the dual graph; simulation on the duals
compare(G, H; templates, system, optimizer)      # the one entry point: every lift, a Comparison

# --- A refinement (src/refinements/catalogue/): one method to implement.
refine(R, graph, edges) / refine(R, graph)       # returns a Refined: the graph and the origin of every node
dual(R)                                          # DualRefinement; every backward atom
refine(template, graph, problem; strategy)       # the one entry point: the loop
```

The four atoms are the partial lifts of Athanasopoulos & Jungers edge for edge, and
`test/refinements/reference.jl` pins them against the reference implementation of Roy's
repository, self-loops included. Two things the paper's degree assumptions leave open are decided
there too: a node left without edges is deleted, and a locus of several edges is the lift applied
edge by edge with the loop last. A refinement has no `requirements` and no `is_valid`; do not add
them. A strategy for `refine` is any callable `(certificate; atol) -> Vector{Refined}`. The min
and max lifts are never built to decide anything: a relation decides in polynomial time what they
exhibit in exponential size, and the sum lift over every size is a linear program.

**`refute` will not be `certify`.** A refutation routine samples looking for a violation: it is a
cheap way to learn you are wrong, and finding nothing proves nothing. `certify` solves for the
guarantee. When refutation lands, keep both visible in the API and never present one as the other —
conflating them is how unsound results ship. The sampling half is already here: `simulate` runs a
system along one switching sequence, filed under `src/systems/` because nothing about it certifies.

Two placements that are deliberate rather than obvious: the conic partition lives with its
template, not under `graphs/`, because it partitions the state space and is indexed by node only
because each node gets one; and `common.jl` is top-level because `common` reads graph, template
and problem at once. Avoid `utils.jl` and `*_helper.jl`: both existed here and both were junk
drawers.

## 6. Tests, formatting, docs

- Every test file is standalone-runnable and wired into `TEST_FILES` in `test/runtests.jl`.
- Format before every commit; CI fails on any diff.
- Iterate in one long-lived `julia --project=test` session with Revise rather than relaunching
  Julia: a cold start costs about 30 s and `Pkg.test()` adds Aqua's probe on top. Run the cold
  `Pkg.test()` once at the end, as the gate.
- A stale `Manifest.toml` — it is gitignored — fails `Pkg.test()` before any test runs; `rm` it
  and `Pkg.resolve()` in the environment that failed, root, `test/` or `docs/`.
- **Every name reachable as `PathCompleteCertificates.name` needs a docstring.** The package
  exports nothing deliberately, so Documenter's `checkdocs = :all` cannot see a name that has no
  docstring at all — eight docstrings written as `raw"""`, which never attach, once went missing
  exactly that way. `test/docstrings.jl` is the gate for that: it walks every non-underscore
  reachable name and fails on any that is undocumented.
- **Every docstring must land in an `@autodocs` block under `docs/src/reference/`.** This one
  `checkdocs = :all` does enforce, by failing the docs build — so a new file in `src/` needs a
  `Pages` entry as well as tests.
- **Verify every citation in the PDF before writing it.** No definition or theorem number goes
  into a docstring or a page without being read in the paper.
