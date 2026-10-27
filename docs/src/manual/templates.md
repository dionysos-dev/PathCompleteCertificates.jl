```@meta
CurrentModule = PathCompleteCertificates
```

# Choosing a template

```@setup running
import PathCompleteCertificates as PCC
import Clarabel, HiGHS
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = PCC.switched_system(A)
problem = PCC.StabilityProblem(system)
graph = PCC.common_graph(system)
```

The template is the family the node functions are drawn from: for stability, a
[SetProg](https://github.com/blegat/SetProg.jl) set family, whose sets' gauges
are the node functions. This page shows what it changes, lists the templates
and how to build each, and helps you choose.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, `problem = PCC.StabilityProblem(system)`
and `graph = PCC.common_graph(system)`, solved with Clarabel and HiGHS.

## What a template changes

The template fixes the shape of the node functions. It also sets the program
to solve, and so the solver, and it changes the bound:

```@example running
quadratic = PCC.certify(PCC.QuadraticTemplate(), graph, problem; optimizer = Clarabel.Optimizer)
copositive = PCC.certify(PCC.LinearCopositiveTemplate(), graph, problem; optimizer = HiGHS.Optimizer)
quadratic.rate, copositive.rate
```

The quadratic template solves a semidefinite program, the linear copositive
template a linear program; the latter applies here because the matrices have
nonnegative entries.

The level set ``V(x) = 1`` of the certificate that four templates find on the
running example shows their shapes:

```@setup running
using Plots
using SumOfSquares, DynamicPolynomials

function shapes_figure(system, problem, graph)
    @polyvar x[1:2]
    templates = [
        "quadratic" => (PCC.QuadraticTemplate(), Clarabel.Optimizer),
        "sum of squares, degree 2" => (PCC.SumOfSquaresTemplate(2, x), Clarabel.Optimizer),
        "parallel faces" =>
            (PCC.ParallelFacesPolyhedralTemplate([[1.0 1.0; -1.0 1.0]]), HiGHS.Optimizer),
        "conic polyhedral" =>
            (PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(2)]), HiGHS.Optimizer),
    ]
    figure = plot(; aspect_ratio = :equal, framestyle = :box, legend = :outerbottom,
                  size = (520, 640))
    for (name, (template, optimizer)) in templates
        certificate = PCC.certify(template, graph, problem; optimizer)
        fitted = only(PCC.functions(certificate))
        V(x) = PCC.node_value(problem, fitted, x)
        p = PCC.homogeneity_degree(template)
        # V is homogeneous of degree p: scaling each direction d by V(d)^(-1/p)
        # lands on the level set V = 1.
        points = [d ./ V(d)^(1 / p)
                  for d in ([cos(t), sin(t)] for t in range(0, 2pi; length = 400))]
        plot!(figure, first.(points), last.(points); lw = 2, label = name)
    end
    return figure
end
```

```@example running
shapes_figure(system, problem, graph) # hide
```

## The templates

| Template | Node function | Systems | Program | Problems |
| :-- | :-- | :-- | :-- | :-- |
| [`QuadraticTemplate`](@ref)`()` | ``x^\top P x`` | all | semidefinite | stability, safety, optimal control |
| [`SumOfSquaresTemplate`](@ref)`(d, x)` | a sum of squares of polynomials of degree ``d`` | all | semidefinite | stability |
| [`LinearCopositiveTemplate`](@ref)`()` | ``c^\top x`` | positive | linear | stability |
| [`DualCopositiveTemplate`](@ref)`()` | ``\max_i x_i / v_i`` | positive | linear | stability |
| [`ParallelFacesPolyhedralTemplate`](@ref)`(n_nodes, n)` | ``\max_k \lvert (G x)_k \rvert / w_k`` | all | linear | stability |
| [`ConicPolyhedralTemplate`](@ref)`(partitions)` | ``\max_i \lvert p_i^\top x \rvert`` | all | linear | stability |
| `Ellipsoid(symmetric = true, piecewise = P)` | quadratic on each cone of ``P`` | all | semidefinite | stability |
| `Polytope(symmetric = true, piecewise = P)` | linear on each cone of ``P`` | all | linear | stability |

Each constructor returns a SetProg family: `QuadraticTemplate()`, for
instance, is `Ellipsoid(symmetric = true)`. The last two rows are SetProg
families passed directly, with the cones over the facets of a polytope ``P``.
A positive system has matrices with nonnegative entries, so its trajectories
that start in the nonnegative orthant stay there; the copositive functions are
defined on that orthant. The sum-of-squares template needs a package of its
own: see [Installation](@ref).

## How to choose

- **Start with** `QuadraticTemplate()`. It applies to every system and every
  problem.
- **For a positive system**, `LinearCopositiveTemplate()` and
  `DualCopositiveTemplate()` solve linear programs.
- **For a polyhedral function on any system**, two templates solve linear
  programs:
  - `ParallelFacesPolyhedralTemplate(n_nodes(graph), n)` fixes the normals of
    the faces: the axes by default, or the rows of a matrix ``G`` per node,
    given instead. The normals matter: on the running example, the axes give
    a bound of about ``1.30``, above one, and the diagonals,
    `ParallelFacesPolyhedralTemplate([[1.0 1.0; -1.0 1.0]])`, about ``0.92``;
  - `ConicPolyhedralTemplate(partitions)` fixes, at each node, a partition of
    the space into the cones over the facets of a polytope, on each of which
    the function is linear; in the plane, [`planar_conic_partition`](@ref)
    builds one.
- **For a polynomial function**, `SumOfSquaresTemplate(d, x)`, with the
  variables `@polyvar x[1:n]` of DynamicPolynomials. Degree 1 gives quadratic
  forms.
- **For a function piecewise on cones**, a SetProg family passed directly:
  `Ellipsoid(symmetric = true, piecewise = P)`, quadratic on each cone over a
  facet of the polytope ``P``, or `Polytope(symmetric = true, piecewise = P)`,
  linear on each; see [Use SetProg families](@ref).

Which template gives the lowest bound depends on the system: try several.
[What works with what](@ref) lists the problems and methods each template
supports.

## Adding a template

A new template is a SetProg family: see [Extending the package](@ref).
