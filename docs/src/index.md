```@meta
CurrentModule = PathCompleteCertificates
```

# PathCompleteCertificates.jl

PathCompleteCertificates.jl is a [Julia](https://julialang.org/) package that
computes certificates for **discrete-time switched linear systems** under
arbitrary switching: proofs that the system is stable, that it stays safe, or
that a feedback policy keeps its cost bounded. Each certificate is built on a
path-complete graph, a graph whose paths read every sequence of modes. You
choose the graph, or let the package improve it.

## What it certifies

- **Stability.** An upper bound on the joint spectral radius, the worst
  asymptotic growth rate of the trajectories. A bound below one proves the
  system stable.
- **Safety.** That no trajectory starting in an initial set reaches an unsafe
  set.
- **Optimal control.** A state-feedback policy, and an upper bound on its cost
  for every switching sequence.

## An example

Take the simplest case: a planar switched linear system with two modes,
``x_{k+1} = A_{\sigma(k)} x_k``; the quadratic template,
``V(x) = x^\top P x``; and a graph with one node. Together they give a
stability certificate, a
common quadratic Lyapunov function, whose rate ``\gamma`` is an upper bound on
the joint spectral radius of the system:

```@example
import PathCompleteCertificates as PCC
import Clarabel

A1 = [0.1552 0.0447; 0.7641 0.7472]
A2 = [0.0475 0.9176; 0.1896 0.0185]
system = PCC.switched_system([A1, A2])  # planar switched linear system, two modes

certificate = PCC.certify(
    PCC.QuadraticTemplate(),         # V(x) = xᵀPx at each node
    PCC.common_graph(system),        # one node, one loop per mode
    PCC.StabilityProblem(system);    # V(Aᵢx) ≤ γ² V(x) along each edge
    optimizer = Clarabel.Optimizer,  # the solver of the semidefinite program
)
certificate.rate
```

The bound is below one, so the system is stable under arbitrary switching.

[How a certificate works](@ref) explains the template, the graph and the edge
inequality, and why together they prove stability, safety or a bound on the
cost, for every switching sequence.

## How the documentation is structured

New to the package? Read [Should you use PathCompleteCertificates.jl?](@ref)
and [Installation](@ref), then Part I of the manual.

- **Manual.** How to solve your problem with the package, in three parts:
  - **I. Certify your system with a graph you choose.** Define the system and
    the problem, choose a template and a graph, call [`certify`](@ref), and
    read the certificate. Start at [Systems and problems](@ref).
  - **II. Let the package improve the graph.** When you do not know which
    graph to choose, or want a better bound.
    [Refining the graph](@ref) improves it step by step, applying
    [Lifts](@ref) where the certificate is tight; each lift gives a bound at
    least as good.
  - **III. Going further.** Tools on the framework itself, beyond one system:
    [Comparing graphs](@ref), to prove when possible that a graph gives a bound
    at least as good as another for every system, and [Duality](@ref), which
    reverses the graph, transposes the system, and turns a certificate into
    another at the same rate.

  [What works with what](@ref) says which templates each problem accepts,
  which lifts are valid for each template, and where refinement and comparison
  apply.
- **Tutorials.** One problem solved from start to end per page.
- **Background.** The theory behind the package, and the papers it implements.
- **API Reference.** Every function, from its docstring.
- **Developers.** How to set up, test and extend the package.

## For researchers

The package brings together, in one implementation, results on path-complete
certificates spread across the literature; the [Bibliography](@ref) says which
paper each part comes from. It is built to receive new methods:
[What works with what](@ref) shows the combinations not yet covered, and
[Extending the package](@ref) how to add a template, a problem, a lift or a
refinement algorithm.

## Getting help

For questions, bug reports and suggestions, open an issue on
[GitHub](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues).

## Citing

A paper describing the package is in preparation. Until it is published,
please cite the papers of the methods you use; the [Bibliography](@ref) says
what the package takes from each.

## License

PathCompleteCertificates.jl is licensed under the
[MIT license](https://github.com/dionysos-dev/PathCompleteCertificates.jl/blob/master/LICENSE).
It is used with solvers and other packages that have their own licenses;
consult their repositories for the licenses that apply.
