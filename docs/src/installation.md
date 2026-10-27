```@meta
CurrentModule = PathCompleteCertificates
```

# Installation

## Install Julia

Download Julia from [julialang.org](https://julialang.org/downloads/). The
package needs Julia 1.10 or later. Two releases are offered:

- the **current stable release**, the newest: most users should install it,
  and update when a new version comes out;
- the **long-term support release**, older but still receiving bug fixes: for
  machines that are rarely updated, such as computers managed by an IT
  department.

New to Julia? Start with the
[Getting started](https://docs.julialang.org/en/v1/manual/getting-started/)
page of its manual. The commands below are typed at the `julia>` prompt.

## Install PathCompleteCertificates.jl

Work in one environment per project rather than in the global environment, so
that the packages of one project do not constrain those of another:

```julia
import Pkg
Pkg.activate("my_project")
```

The package is not registered yet. Install it from its repository:

```julia
Pkg.add(url = "https://github.com/dionysos-dev/PathCompleteCertificates.jl")
```

In every new Julia session, run `Pkg.activate("my_project")` again before
`using PathCompleteCertificates`. Update the package with
`Pkg.update("PathCompleteCertificates")`.

## Install a solver

Every certificate is computed by a solver, through [JuMP](https://jump.dev/).
Two open-source solvers cover all the templates:

- [Clarabel](https://github.com/oxfordcontrol/Clarabel.jl), for semidefinite
  programs: the quadratic and sum-of-squares templates, and the SetProg
  ellipsoids and polynomial sets;
- [HiGHS](https://github.com/jump-dev/HiGHS.jl), for linear programs: the
  copositive and polyhedral templates, and the SetProg polytopes.

```julia
Pkg.add(["Clarabel", "HiGHS"])
```

Pass the solver as `optimizer`, for example `optimizer = Clarabel.Optimizer`.
Any other JuMP solver for these programs works, such as the commercial solver
MOSEK; JuMP keeps the
[list of solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).

To check the installation, run [the example of the home page](@ref "An example").

## Optional packages

A few features need another package, installed with `Pkg.add` and loaded:

| To use | Install and load |
| :-- | :-- |
| [`SumOfSquaresTemplate`](@ref) | `SumOfSquares`, and a polynomial package such as `DynamicPolynomials` |
| SetProg families directly, such as piecewise ellipsoids | `SetProg`, which the package already depends on |
| plots of a [`Trajectory`](@ref) | `Plots` |

For example, `Pkg.add(["SumOfSquares", "DynamicPolynomials"])`, then
`using SumOfSquares, DynamicPolynomials`.

## Common installation issues

**When in doubt, update.** Run `Pkg.update()`, then restart Julia: packages
already loaded are not replaced until then.

**Check the versions.** `Pkg.status()` lists the packages of the environment
and their versions. Include its output when you
[open an issue](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues).

**"Unsatisfiable requirements detected".** Two packages of the environment
require incompatible versions of a third. Install in a new environment, or see
[resolving version conflicts](https://pkgdocs.julialang.org/v1/managing-packages/#conflicts)
in the Pkg documentation.

**A package was downgraded.** Adding a package that does not support the
latest version of another makes Pkg install an older version of that other
package. Read the output of `Pkg.add`, which lists every version it changes.
