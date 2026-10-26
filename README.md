<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/src/assets/banner-dark.svg">
  <img src="docs/src/assets/banner.svg" alt="PathCompleteCertificates.jl" width="720">
</picture>

| **Documentation** | **Build Status** |
|:-----------------:|:----------------:|
| [![][docs-latest-img]][docs-latest-url] | [![Build Status][build-img]][build-url] [![Codecov][codecov-img]][codecov-url] [![Aqua QA][aqua-img]][aqua-url] |

[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev

[build-img]: https://github.com/dionysos-dev/PathCompleteCertificates.jl/actions/workflows/ci.yml/badge.svg?branch=master
[build-url]: https://github.com/dionysos-dev/PathCompleteCertificates.jl/actions?query=workflow%3ACI
[codecov-img]: https://codecov.io/github/dionysos-dev/PathCompleteCertificates.jl/branch/master/graph/badge.svg
[codecov-url]: https://app.codecov.io/github/dionysos-dev/PathCompleteCertificates.jl
[aqua-img]: https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg
[aqua-url]: https://github.com/JuliaTesting/Aqua.jl

<!-- Deliberately absent until they would mean something:
     * a `docs-stable` badge -- there is no released version, so the URL 404s;
     * PkgEval -- the report only exists once the package is in the General
       registry, so the badge renders empty until then.
     Add both at registration (plan P7), not before. -->

Tools for constructing, comparing and refining certificates for switched systems within the
**path-complete framework**, with the two components of a certificate, the template and the
graph, both explicit.

## What it does

A path-complete certificate is three things: a **labelled graph** whose labels are the modes
of a switched system, a function at each node drawn from a **template**, and one **inequality
along each edge**, fixed by the **problem**. When every admissible switching sequence can be
read as a path in the graph, the local inequalities imply a property of the whole system. Only
the inequality changes between stability, safety and optimal control.

What the package adds to that framework is the graph as an object in its own right:

| | |
| :-- | :-- |
| **Certify** | stability, safety or optimal control on a graph you supply, with quadratic, copositive, polyhedral or sum-of-squares templates |
| **Build** | De Bruijn graphs, the common Lyapunov function graph, duals, graphs reading words |
| **Refine** | grow a graph where its certificate is tight, by the lifts and algorithms of the literature, until the bound is proved to be the joint spectral radius |
| **Compare** | decide whether one graph is guaranteed no worse than another for a template, with the simulation that proves it: a map, a relation or an integer matrix |

## How it relates to the other tools

| | Question it answers |
| :-- | :-- |
| **[SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl)** | How large is the joint spectral radius, and how tightly can I bound it? Invariant sets via sum-of-squares. |
| **[JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)** (MATLAB) | The same question, and the baseline the literature is written against. |
| **This package** | Path-complete graphs as objects: build them, compare two of them, refine one iteratively, and attach certificates of any of the three problems to them. |

The first two use a path-complete graph, when they do, as an internal device for getting a
bound. This one makes the graph the thing you work on.

## Installation

Not yet registered.

```julia
] add https://github.com/dionysos-dev/PathCompleteCertificates.jl
```

## Documentation

The [development documentation](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/)
covers the manual, the examples and the API reference. It also carries the
[Developer Docs](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/developers/setup/),
with the setup, the conventions and the Git workflow.

There is no released version yet, so there is no stable documentation.

## Contributing

Contributions are welcome. Please open an
[issue](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues) to report a bug or
discuss a feature, and see the Developer Docs for the setup, conventions and Git workflow.

Stability certificates use [SetProg](https://github.com/blegat/SetProg.jl)
set families directly. SetProg owns their variables, inclusions and fitted gauges;
this package owns the systems, graphs, lifts and refinement algorithms.
Safety and optimal control retain their matrix models until their migration.
See the [conventions](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/developers/conventions/)
for extending the package.

## References

The [bibliography](https://dionysos-dev.github.io/PathCompleteCertificates.jl/dev/bibliography/)
lists every paper the package implements, grouped by what each one underwrites: the
predicates, the templates, the problems, the lifts and the refinement algorithms.

## Acknowledgements

This project has received funding from the European Research Council (ERC) under the European
Union's Horizon 2020 research and innovation programme under grant agreement No 864017 — L2C.
