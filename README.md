# PathCompleteCertificates.jl

Certificates for switched systems built on **path-complete graphs**.

> **Status: under construction.** The scaffolding is in place; the graph layer is next.

## What it does

A path-complete certificate is always the same three things: a **labelled graph**, a function
`V_α` drawn from a **template** at each node, and one **inequality along each edge**. The graph
is *path-complete* when every switching sequence of the system is readable as a path in it —
that is the soundness condition.

What changes between proving stability, bounding a value function, and certifying safety is
only the edge inequality:

| Objective | Edge inequality on `(α, β, i)` |
| :-- | :-- |
| Stability | `V_α(x) ≥ V_β(A_i x)` |
| Optimal control | `V_α(x) ≥ c(x) + V_β(f_i(x))` |

So the package is built along two independent axes — **template** (what the node functions
are) and **objective** (what the edge inequality says) — which compose as a product. Adding an
objective is one method; adding a template is two.

## How it relates to the other tools

| | Question it answers |
| :-- | :-- |
| **[SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl)** | How large is the joint spectral radius, and how tightly can I bound it? Invariant sets via sum-of-squares. |
| **JSR Toolbox** (MATLAB) | The same question, and the baseline the literature is written against. |
| **This package** | Path-complete graphs as objects: build them, compare two of them, order them, refine one iteratively, and attach certificates of any objective to them. |

The first two use a path-complete graph as an internal device for getting a bound. This one
makes the graph the thing you work on. Where a joint-spectral-radius number is wanted, the
other two remain the reference.

## Installation

Not yet registered.

```julia
] add https://github.com/dionysos-dev/PathCompleteCertificates.jl
```

## References

- Ahmadi, Jungers, Parrilo, Roozbehani — *Joint spectral radius and path-complete graph
  Lyapunov functions*, SIAM J. Control Optim., 2014
- Philippe, Athanasopoulos, Angeli, Jungers — [*On Path-Complete Lyapunov Functions: Geometry
  and Comparison*](https://arxiv.org/abs/1712.00381)
- Debauche, Della Rossa, Jungers — [*Comparison of Path-Complete Lyapunov Functions via
  Template-Dependent Lifts*](https://arxiv.org/abs/2110.13474)
- Jongeneel, Jungers — [*Ordering and refining path-complete Lyapunov functions through
  composition lifts*](https://arxiv.org/abs/2503.18189)
- Ninite, Banse, Jungers — [*A Path-Complete Approach for Optimal Control of Switched
  Systems*](https://arxiv.org/abs/2602.04310)
- Anand, Jungers, Zamani, Allgöwer — [*On the Completeness and Ordering of Path-Complete
  Barrier Functions*](https://arxiv.org/abs/2503.19561)

## License

MIT
