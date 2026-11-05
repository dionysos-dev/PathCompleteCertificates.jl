```@meta
CurrentModule = PathCompleteCertificates
```

# Choosing a template

```@setup running
using PathCompleteCertificates
import Clarabel, HiGHS
A = [[0.1552 0.0447; 0.7641 0.7472], [0.0475 0.9176; 0.1896 0.0185]]
system = switched_system(A)
problem = StabilityProblem(system)
graph = common_graph(system)
```

The template is the family the node functions are drawn from. In the program
that [`certify`](@ref) solves, it gives the variables and sets the kind of
program: semidefinite, linear or second-order cone. With the graph, it
influences how good the certificate can be and how much it costs (see
[How a certificate works](@ref)). This page shows what a template changes,
lists the templates, and helps you choose.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, `problem = StabilityProblem(system)`
and `graph = common_graph(system)`, solved with Clarabel and HiGHS.

## What a template changes

The template fixes the shape of the node functions. It changes the bound and
the kind of program, and so the solver:

```@example running
quadratic = certify(QuadraticTemplate(), graph, problem; optimizer = Clarabel.Optimizer)
copositive = certify(LinearCopositiveTemplate(), graph, problem; optimizer = HiGHS.Optimizer)
quadratic.rate, copositive.rate
```

The quadratic template solves a semidefinite program, with Clarabel, and the
linear copositive template a linear program, with HiGHS. The latter applies
here because the matrices have nonnegative entries (see
[What works with what](@ref)).

The unit sets ``\{x : V(x) \le 1\}`` of the certificates that four templates
find on the running example show their shapes:

```@setup running
using Plots
import SumOfSquares

function shapes_figure(system, problem, graph)
    templates = [
        "quadratic" => (QuadraticTemplate(), Clarabel.Optimizer),
        "sum of squares, degree 4" => (SumOfSquaresTemplate(2), Clarabel.Optimizer),
        "dual piecewise linear, on the diagonals" =>
            (DualPiecewiseLinearTemplate([[1.0 1.0; -1.0 1.0]]), HiGHS.Optimizer),
        "piecewise linear" =>
            (PiecewiseLinearTemplate([planar_conic_partition(2)]), HiGHS.Optimizer),
    ]
    figure = plot(; aspect_ratio = :equal, framestyle = :box, legend = :outerbottom,
                  size = (520, 640))
    for (name, (template, optimizer)) in templates
        certificate = certify(template, graph, problem; optimizer)
        fitted = only(functions(certificate))
        V(x) = node_value(problem, fitted, x)
        δ = PathCompleteCertificates.homogeneity_degree(template)
        # V is homogeneous of degree δ: scaling each direction d by V(d)^(-1/δ)
        # lands on the level set V = 1.
        points = [d ./ V(d)^(1 / δ)
                  for d in ([cos(t), sin(t)] for t in range(0, 2pi; length = 400))]
        plot!(figure, first.(points), last.(points); lw = 2, label = name)
    end
    return figure
end
```

```@example running
shapes_figure(system, problem, graph) # hide
```

The data of a template matter too. Given a matrix per node,
`DualPiecewiseLinearTemplate` fixes the normals of the faces of its functions
to the rows of the matrix. With the axes, and with the diagonals of the
figure:

```@example running
on_axes = DualPiecewiseLinearTemplate(n_nodes(graph), 2)
on_diagonals = DualPiecewiseLinearTemplate([[1.0 1.0; -1.0 1.0]])
[certify(t, graph, problem; optimizer = HiGHS.Optimizer).rate for t in (on_axes, on_diagonals)]
```

## The templates

| Constructor | Node function ``V_s(x)`` | Variables | ``\delta`` | Unit set ``\Omega_s`` |
| :-- | :-- | :-- | :-: | :-- |
| [`QuadraticTemplate`](@ref)`()` | ``x^\top P_s x`` | ``P_s`` | 2 | ``\mathcal{E}(P_s)`` |
| [`PiecewiseQuadraticTemplate`](@ref)`(P)` | ``x^\top P_{s,k} x`` on ``\mathcal{C}_{s,k}`` | ``P_{s,k}``, all ``k`` | 2 | ``\operatorname{Pw}_s\big((\mathcal{E}(P_{s,k}))_k\big)`` |
| [`SumOfSquaresTemplate`](@ref)`(r)` | ``b_r(x)^\top Q_s \, b_r(x)`` | ``Q_s \succeq 0`` | ``2r`` | ``\{x : V_s(x) \le 1\}`` |
| [`PiecewiseLinearTemplate`](@ref)`(P)` | ``a_{s,k}^\top x`` on ``\mathcal{C}_{s,k}`` | ``a_{s,k}``, all ``k`` | 1 | ``\operatorname{Pw}_s\big((\mathcal{H}(a_{s,k}))_k\big)`` |
| [`DualPiecewiseLinearTemplate`](@ref)`(P)` | ``g_{\Omega_s}(x)`` | ``a_{s,k}``, all ``k`` | 1 | ``\operatorname{Pw}_s\big((\mathcal{H}(a_{s,k}))_k\big)^\circ`` |
| [`LinearCopositiveTemplate`](@ref)`()` | ``c_s^\top x``, on ``\mathbb{R}^n_+`` | ``c_s \ge 0`` | 1 | ``\mathcal{H}(c_s) \cap \mathbb{R}^n_+`` |
| [`DualCopositiveTemplate`](@ref)`()` | ``\max_j x_j / v_{s,j}``, on ``\mathbb{R}^n_+`` | ``v_s > 0`` | 1 | ``\prod_j \, [0, v_{s,j}]`` |

The table writes ``\mathcal{E}(P) = \{x : x^\top P x \le 1\}`` for an
ellipsoid and ``\mathcal{H}(a) = \{x : a^\top x \le 1\}`` for a half-space,
and ``\delta`` is the degree of the node functions. The constructors also
make the node functions symmetric, and normalize them to exclude
``V_s \equiv 0``, which the table does not show.
[What works with what](@ref) gives the systems and problems each template
supports, the program it gives for each, and where [`refine`](@ref) applies.
The sum-of-squares and piecewise quadratic templates need the SumOfSquares
package loaded (see [Installation](@ref)). The templates fall into four
groups.

**Quadratic and polynomial.** The quadratic template gives ellipsoids. For
`SumOfSquaresTemplate(r)`, ``b_r(x)`` is the vector of the monomials of degree
``r``, and ``Q_s \succeq 0`` makes ``V_s`` a sum of squares
[parrilo2008approximation](@cite): ``r = 1`` gives the quadratic forms, and
each higher ``r`` adds variables. `convex = true` also makes each node
function convex, for optimal control (see [What works with what](@ref)).

**Piecewise.** A polytope ``\mathcal{P}_s`` containing the origin in its
interior defines a cone on each of its facets ``\mathcal{F}_{s,k}``, and a
piecewise set keeps one set ``Z_k`` on each cone:

```math
\mathcal{C}_{s,k} = \{t y : t \ge 0,\ y \in \mathcal{F}_{s,k}\}, \qquad
\operatorname{Pw}_s\big((Z_k)_k\big) = \textstyle\bigcup_k \big(Z_k \cap \mathcal{C}_{s,k}\big).
```

On each cone, the piecewise quadratic template keeps an ellipsoid and the
piecewise linear template a half-space, so that ``V_s`` is quadratic or linear
on each cone. Continuity and convexity are imposed across adjacent cones. The
argument `P` gives the polytopes ``\mathcal{P}_s``, one per node, and
[`planar_conic_partition`](@ref)`(q)` builds a planar one with
``8 \cdot 2^{q-1}`` facets.

**Dual piecewise linear.** The dual piecewise linear template is the polar of
the piecewise linear one, on the same polytopes, and [`dual`](@ref) maps each
to the other (see [Duality](@ref)). Fixing the directions of the vertices of
one fixes the normals of the faces of the other: these are the two polyhedral
parameterizations of [athanasopoulos2019polyhedral](@citet). Two other
constructors build the polytopes from matrices.
`DualPiecewiseLinearTemplate(matrices)`, with one invertible matrix ``G_s``
per node, takes the rows of ``G_s`` and their opposites as the vertices of
``\mathcal{P}_s``, so that the unit sets are parallelotopes with faces normal
to the rows of ``G_s``. `DualPiecewiseLinearTemplate(n_nodes, n)` sets
``G_s = I``, which gives boxes.

**Copositive.** For positive systems, the nonnegative orthant is invariant,
and the copositive templates restrict the node functions to it
[debauche2021comparison; Def. 11](@cite). The linear copositive template has
unit set ``\mathcal{H}(c_s) \cap \mathbb{R}^n_+``. The dual copositive
template takes its polar within the orthant, the box ``\prod_j [0, v_{s,j}]``.

## How to choose

- **Start with** `QuadraticTemplate()`. It applies to every system and every
  problem.
- **For the stability of a positive system**, `LinearCopositiveTemplate()`
  and `DualCopositiveTemplate()` solve linear programs.
- **For a polyhedral function on any system**, `PiecewiseLinearTemplate(P)`
  or `DualPiecewiseLinearTemplate(P)`, whose data change the bound, as above.
- **For a polynomial function**, `SumOfSquaresTemplate(r)`, of degree ``2r``.
- **For a function quadratic on each cone**, `PiecewiseQuadraticTemplate(P)`.

Which template gives the lowest bound depends on the system, and a template
with more variables builds a larger program: try several.

## Templates are SetProg families

Each constructor returns a [SetProg](https://github.com/blegat/SetProg.jl)
family of sets, or, for the templates with data per node, a vector of
families, one per node: `QuadraticTemplate()` is
`SetProg.Ellipsoid(symmetric = true)`, and `PiecewiseLinearTemplate([P])` is
`[SetProg.Polytope(symmetric = true, piecewise = P)]`. A SetProg family can
also be passed directly, without a constructor (see
[Try a richer template](@ref)). To write one, run `Pkg.add("SetProg")` and
`import SetProg`. The package depends on SetProg, so nothing new is
downloaded, but your environment must list it for Julia to load it by name.
Load it with `import` rather than `using`, which would hide the package's
`dual`, `is_valid` and `lift` behind SetProg's.

## Adding a template

A new template is a SetProg family: see [Extending the package](@ref).
