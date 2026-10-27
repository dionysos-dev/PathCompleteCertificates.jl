```@meta
CurrentModule = PathCompleteCertificates
```

# Should you use PathCompleteCertificates.jl?

PathCompleteCertificates.jl computes certificates for discrete-time switched
linear systems under arbitrary switching: proofs that hold for every sequence
of modes. This page helps you decide whether it fits your problem.

## When to use it

Use it when two conditions hold:

1. your system is a discrete-time switched linear system,
   ``x_{k+1} = A_{\sigma(k)} x_k`` or
   ``x_{k+1} = A_{\sigma(k)} x_k + B_{\sigma(k)} u_k``, and any sequence of
   modes may occur;
2. you want a proof rather than simulations: that the system is stable, that
   it stays safe, or that a feedback policy keeps its cost bounded.

It fits best when, in addition:

- you want to choose the graph of the certificate, or let the package improve
  it;
- you want node functions beyond quadratic forms: sums of squares, copositive
  functions for positive systems, polyhedral norms, or the piecewise quadratic
  and piecewise linear functions of
  [SetProg.jl](https://github.com/blegat/SetProg.jl);
- you want to choose the solver: any JuMP solver for the kind of program the
  template sets, semidefinite or linear;
- you study the path-complete framework itself, and want to compare graphs,
  use duality, benchmark methods from different papers, or add a template, a
  problem or an algorithm.

Not every combination of problem, template and method is supported yet:
[What works with what](@ref) lists them.

## When not to use it

This package is not the right tool when:

- **The switching is constrained**, for instance by an automaton. Support is
  planned, see
  [issue #45](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues/45).
  Until then, [SwitchOnSafety.jl](https://github.com/blegat/SwitchOnSafety.jl)
  bounds the joint spectral radius under constrained switching, and the MATLAB
  [CSSystem toolbox](https://www.mathworks.com/matlabcentral/fileexchange/52723-the-cssystem-toolbox)
  analyses the stability of systems with constrained switching sequences.
- **You need lower bounds from products of matrices, or the exact joint
  spectral radius.** No method computes the joint spectral radius exactly for
  every set of matrices. This package gives upper bounds, and lower bounds only
  from the cycles of a certificate, which sometimes prove the upper bound
  exact. The MATLAB
  [JSR Toolbox](https://www.mathworks.com/matlabcentral/fileexchange/33202-the-jsr-toolbox)
  and SwitchOnSafety.jl give lower bounds from products, with Gripenberg's
  algorithm among others, and the function `ipa` of the MATLAB
  [ttoolboxes](https://gitlab.com/tommsch/ttoolboxes) returns the exact value
  when it finds an invariant polytope.
- **You need controlled invariant sets.** SwitchOnSafety.jl computes them for
  hybrid systems.
- **You need reachable sets rather than certificates.** See
  [ReachabilityAnalysis.jl](https://github.com/JuliaReach/ReachabilityAnalysis.jl).
- **Your system evolves in continuous time, is nonlinear, or is a hybrid
  system other than a switched linear one**, for instance with switching that
  depends on the state, or with resets. This package does not cover these
  systems.
