# PathCompleteCertificates.jl

| **Documentation** | **Build Status** |
|:-----------------:|:----------------:|
| [![][docs-latest-img]][docs-latest-url] | [![Build Status][build-img]][build-url] [![Codecov][codecov-img]][codecov-url] [![Aqua QA][aqua-img]][aqua-url] |

[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev

[build-img]: https://github.com/dionysos-dev/PathCompleteCertificates.jl/actions/workflows/ci.yml/badge.svg?branch=master
[build-url]: https://github.com/dionysos-dev/PathCompleteCertificates.jl/actions?query=workflow%3ACI
[codecov-img]: https://codecov.io/github/dionysos-dev/PathCompleteCertificates.jl/coverage.svg
[codecov-url]: https://app.codecov.io/github/dionysos-dev/PathCompleteCertificates.jl
[aqua-img]: https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg
[aqua-url]: https://github.com/JuliaTesting/Aqua.jl

<!-- Deliberately absent until they would mean something:
     * a `docs-stable` badge -- there is no released version, so the URL 404s;
     * PkgEval -- the report only exists once the package is in the General
       registry, so the badge renders empty until then.
     Add both at registration (plan P7), not before. -->

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

## Documentation

The [development documentation](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/)
covers the manual, the examples and the API reference. It also carries the
[Developer Docs](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/developers/setup/) —
setup, conventions and the Git workflow.

There is no released version yet, so there is no stable documentation.

## Contributing

Contributions are welcome. Please open an
[issue](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues) to report a bug or
discuss a feature, and see the Developer Docs for the setup, conventions and Git workflow.

One thing to read before writing code: the package is organised along **two independent axes** —
*template* (what the node functions are) and *objective* (what the edge inequality says). Adding an
objective is one method; adding a template is two. The
[conventions](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/developers/conventions/)
page explains why, and what goes wrong when the structure is ignored.

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

## Acknowledgements

This project has received funding from the European Research Council (ERC) under the European
Union's Horizon 2020 research and innovation programme under grant agreement No 864017 — L2C.

## License

MIT
