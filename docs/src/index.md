```@meta
CurrentModule = PathCompleteCertificates
```

# PathCompleteCertificates.jl

Certificates for switched systems built on **path-complete graphs**.

## The idea

A path-complete certificate is always three things:

1. a **labelled graph**, whose labels are the modes of the switched system;
2. a function `V_α` drawn from a **template** at each node;
3. one **inequality along each edge**.

Only the edge inequality changes between problems:

| Problem | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ γ⁻ᵈ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |
| Safety | `B_α(x) ≥ B_β(A_i x)`, plus separation of the initial and unsafe sets |

The graph is **path-complete** when every switching sequence is readable as a
path in it ([`is_path_complete`](@ref)). That is the soundness condition —
without it the inequalities certify nothing.

So the package has two independent axes, not one hierarchy:

- **[template](@ref Templates)** — what the node functions are;
- **[problem](@ref Problems)** — what the edge inequality says.

They compose as a product. Not every pair is wired up yet:
[What works with what](@ref) is the table.

## Where to start

- **New here?** [Switched systems: the four kinds](@ref), then
  [Stability: a first certificate](@ref).
- **What do the axes buy?** [The two axes, drawn](@ref) — three templates on one
  graph, one template on four graphs.
- **Looking for a function?** [Graph reference](@ref),
  [Template reference](@ref), [Problem reference](@ref),
  [Systems and aggregation](@ref).

## Reading a negative answer

- A bound is always an **upper** bound. `is_stable` returning `false` means no
  certificate was found *in this template on this graph* — not that the system
  is unstable. On a rotation scaled by `0.9`, [`PolyhedralTemplate`](@ref)
  certifies nothing while [`ConicPolyhedralTemplate`](@ref) reaches `0.901`.
- A graph that is not path-complete for the system's alphabet is **rejected**,
  not silently certified.

## Status

Early. Stability, safety and optimal control work for the templates above. The
differentiating work — comparing, ordering and refining path-complete graphs —
is not here yet.

## How it relates to the other tools

[SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl) and the MATLAB
[JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)
treat the path-complete graph as an internal device for getting a
joint-spectral-radius bound. Here the graph is the object of study — something
you build, compare, order and refine.

```@docs
PathCompleteCertificates
```
