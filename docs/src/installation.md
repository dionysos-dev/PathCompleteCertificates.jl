```@meta
CurrentModule = PathCompleteCertificates
```

# Installation

## Install Julia

Install Julia as [julialang.org](https://julialang.org/downloads/) describes.
Its installers also install juliaup, which keeps Julia up to date: run
`juliaup update` in a terminal when a new version comes out.

The package needs Julia 1.10 or later, so both releases offered work:

- the **current stable release**, the newest, which most users should
  install;
- the **long-term support release**, older but still receiving bug fixes, for
  machines that are rarely updated, such as computers managed by an IT
  department; `juliaup add lts` installs it.

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

In every new Julia session, activate the environment again, as above, then
load the package:

```julia
import PathCompleteCertificates as PCC
```

The package exports nothing, so its functions take the prefix, as in
`PCC.certify`; this documentation does the same. Update the package with
`Pkg.update("PathCompleteCertificates")`.

## Install a solver

Every certificate is computed by a solver, through [JuMP](https://jump.dev/).
Two open-source solvers cover all the templates:

- [Clarabel](https://github.com/oxfordcontrol/Clarabel.jl), for semidefinite
  programs: the quadratic and sum-of-squares templates and piecewise
  ellipsoids, including the log-determinant objective of optimal control;
- [HiGHS](https://github.com/jump-dev/HiGHS.jl), for linear programs: the
  copositive and polyhedral templates, and piecewise polytopes.

```julia
Pkg.add(["Clarabel", "HiGHS"])
```

Load the solver, `import Clarabel`, and pass it as
`optimizer = Clarabel.Optimizer`.
Any other JuMP solver for these programs works, such as the commercial solver
MOSEK; JuMP keeps the
[list of solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).

To check the installation, run [the example of the home page](@ref "An example").

## Optional packages

Two features need another package, installed with `Pkg.add` and loaded:

| To use | Install and load |
| :-- | :-- |
| [`SumOfSquaresTemplate`](@ref) | `SumOfSquares`, and a polynomial package such as `DynamicPolynomials` |
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
