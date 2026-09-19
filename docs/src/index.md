```@meta
CurrentModule = PathCompleteCertificates
```

# PathCompleteCertificates.jl

Certificates for switched systems built on **path-complete graphs**.

## The idea in one paragraph

A path-complete certificate is always the same three things:

1. a **labelled graph**, whose labels are the modes of the switched system;
2. a function `V_α` drawn from a **template** at each node;
3. one **inequality along each edge**.

What changes between proving stability, bounding a value function, and certifying
safety is *only the edge inequality*:

| Problem | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ γ⁻ᵈ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |
| Safety | `B_α(x) ≥ B_β(A_i x)`, plus separation of the initial and unsafe sets |

The graph is **path-complete** when every switching sequence is readable as a path
in it ([`is_path_complete`](@ref)). That is the soundness condition: without it,
the inequalities do not certify anything. It is *weaker* than [`is_complete`](@ref)
and [`is_co_complete`](@ref), which are sufficient conditions that also fix how the
node functions are aggregated.

## Why the package is shaped the way it is

Because only the edge inequality changes, the package is organised along two
independent axes rather than one type hierarchy:

- **template** — what the node functions are ([`QuadraticTemplate`](@ref),
  [`LinearCopositiveTemplate`](@ref), [`PolyhedralTemplate`](@ref),
  [`ConicPolyhedralTemplate`](@ref));
- **problem** — what the edge inequality says ([`StabilityProblem`](@ref),
  [`SafetyProblem`](@ref), [`OptimalControlProblem`](@ref)).

They compose as a product. A **template supplies primitives** — chiefly
[`add_domination!`](@ref), which states that one node function dominates another
under an affine map — and a **problem chooses which to apply, and with what
arguments**. Stability is domination with `scale = γᵈ`; safety is the same on the
homogeneous lift. So a new template is one file under `src/templates/`, a new
problem is one file under `src/problems/`, and neither requires editing the other.

## Reading a negative answer

Two distinctions the API keeps explicit, because conflating them is how unsound
results ship:

- A bound is always an **upper** bound. `is_stable` returning `false` means no
  certificate was found *in this template on this graph* — not that the system is
  unstable. Templates differ enormously here: on a rotation scaled by `0.9`, the
  fixed-facet [`PolyhedralTemplate`](@ref) certifies nothing while
  [`ConicPolyhedralTemplate`](@ref) reaches `0.901` as its partition refines.
- A graph that is not path-complete for the system's alphabet is **rejected**
  rather than silently certified, and the alphabet is the system's, not whichever
  labels the graph happens to carry.

## Status

Early. Stability, safety and optimal control are implemented for the templates
listed above, on graphs represented as `HybridSystems.GraphAutomaton`. The
differentiating work — comparing, ordering and refining path-complete graphs — is
not here yet.

## API

```@index
```

```@autodocs
Modules = [PathCompleteCertificates]
```
