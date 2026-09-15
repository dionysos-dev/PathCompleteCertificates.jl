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

| Objective | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |

The graph is **path-complete** when every switching sequence of the system is
readable as a path in it. That is the soundness condition: without it, the
inequalities do not certify anything.

## Why the package is shaped the way it is

Because only the edge inequality changes, the package is organised along two
independent axes rather than one type hierarchy:

- **template** — what the node functions are (quadratic, polyhedral, …);
- **objective** — what the edge inequality says.

They compose as a product. A new objective is one method, a new template is two,
and their combination costs nothing.

## Status

Under construction. The scaffolding is in place; the graph layer is next.

## API

```@index
```

```@autodocs
Modules = [PathCompleteCertificates]
```
