```@meta
CurrentModule = PathCompleteCertificates
```

# Installation

## Install Julia

Install Julia as [julialang.org](https://julialang.org/downloads/) describes.
Its installers also install juliaup, which keeps Julia up to date: run
`juliaup update` in a terminal when a new version comes out.

The package needs Julia 1.10 or later, so both releases offered work:

- The **current stable release**, the newest, which most users should
  install.
- The **long-term support release**, older but still receiving bug fixes, for
  machines that are rarely updated, such as computers managed by an IT
  department. `juliaup add lts` installs it.

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

Install the latest release from Julia's General registry:

```julia
Pkg.add("PathCompleteCertificates")
```

For the development version, install it from its repository instead:

```julia
Pkg.add(url = "https://github.com/dionysos-dev/PathCompleteCertificates.jl")
```

In every new Julia session, activate the environment again, as above, then
load the package:

```julia
using PathCompleteCertificates
```

The package exports what a user calls, such as `certify`,
`QuadraticTemplate` or `de_bruijn`. The functions that extend it, for a new
template or problem, are written `PathCompleteCertificates.name`. Update the
package with `Pkg.update("PathCompleteCertificates")`.

## Install a solver

Every certificate is computed by a solver, through [JuMP](https://jump.dev/).
Two open-source solvers cover all the templates:

- [Clarabel](https://github.com/oxfordcontrol/Clarabel.jl) solves every
  program the package builds: linear, second-order cone and semidefinite.
- [HiGHS](https://github.com/jump-dev/HiGHS.jl) is faster on the linear
  programs, such as stability with the copositive and polyhedral templates.

```julia
Pkg.add(["Clarabel", "HiGHS"])
```

Load the solver, `import Clarabel`, and pass it as
`optimizer = Clarabel.Optimizer`. For optimal control, turn off Clarabel's
chordal decomposition, which fails on these programs:

```julia
optimizer = () -> Clarabel.Optimizer(chordal_decomposition_enable = false)
```

Any other JuMP solver for these programs works, such as the commercial solver
MOSEK. JuMP keeps the
[list of solvers](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).

To check the installation, run [the example of the home page](@ref "An example").

## Optional packages

Some features need another package, installed with `Pkg.add` and loaded:

| To use | Install and load |
| :-- | :-- |
| [`SumOfSquaresTemplate`](@ref) and [`PiecewiseQuadraticTemplate`](@ref) | `SumOfSquares` |
| SetProg families passed directly, or polytopes of your own | `SetProg` |
| plots of a [`Trajectory`](@ref) | `Plots` |

For example, `Pkg.add("SumOfSquares")`, then `import SumOfSquares`. Load it
with `import` rather than `using`: SumOfSquares exports JuMP's `dual` and
`is_valid`, which would then hide those of the package.

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
