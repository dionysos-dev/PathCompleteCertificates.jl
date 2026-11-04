```@meta
CurrentModule = PathCompleteCertificates
```

# How a certificate works

```@setup running
using PathCompleteCertificates
import Clarabel
A1 = [0.1552 0.0447; 0.7641 0.7472]
A2 = [0.0475 0.9176; 0.1896 0.0185]
system = switched_system([A1, A2])
controlled = switched_system([A1, A2], [[1.0; 0.0;;], [1.0; 0.0;;]])
S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 1.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -25.0]
Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]
```

[`certify`](@ref)`(template, graph, problem)` takes three arguments:

- **the template**: the family the node functions are drawn from.
- **the graph**: one node function per node, and one edge inequality per
  edge, between the functions of its two nodes.
- **the problem**, built from the system: what you want to prove, which sets
  the form of the inequalities and the objective.

The problem is given. The template and the graph are your two choices, and
they influence both how good the certificate can be and how much it costs to
compute. This page defines a path-complete certificate and its common
function, which shows why the certificate holds for every switching sequence.
It then certifies the three problems of the running example with the same
template and graph, and ends with how the package writes their conditions as
set inclusions.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, `controlled`, the sets `S0` and `Su`,
and the costs `Q` and `R`, solved with Clarabel.

## The template and the graph

The template ``\mathcal{V}`` is a parametrized family of functions. Here it is
[`QuadraticTemplate`](@ref): the quadratic forms ``V(x) = x^\top P x``, with
``P`` symmetric. Each problem adds its own conditions.

The graph ``G = (S, E)`` is a directed graph whose edges carry modes: the edge
``(s, d, i) \in E`` goes from its source ``s`` to its destination ``d`` and is
labelled by mode ``i``. It must be **path-complete**: every sequence of modes
is read along some path of the graph. Here, [`common_graph`](@ref) has one
node and a loop per mode.

```@example running
template = QuadraticTemplate()
graph = common_graph(system)
nothing # hide
```

## Path-complete certificates

A **path-complete certificate** on ``G`` is a family ``\{V_s\}_{s \in S}`` of
functions of the template, one node function per node, such that:

- an **edge inequality**, between ``V_s`` and ``V_d`` through mode ``i``,
  holds for every ``x`` and every edge ``(s, d, i)``.
- **node conditions** hold on each ``V_s``, when the problem has them, such
  as positive definiteness.

Every sequence of modes is read along a path of the graph, so the edge
inequalities chain along every trajectory, whatever the switching.

## The common function

The node functions combine into one function of the state, built in the same
way for the three problems, the **common function**

```math
V(x) = \min_{\Pi \in \mathcal{O}} \, \max_{s \in \Pi} V_s(x),
```

where ``\mathcal{O}`` is the set of nodes of the [`observer_graph`](@ref),
each a set of nodes of ``G`` [philippe2019path; Thm. III.8](@cite). On two
kinds of graphs, it simplifies [philippe2019path; Cor. III.3](@cite):

- **on a complete graph,** ``V = \min_s V_s``.
- **on a co-complete graph,** ``V = \max_s V_s``.

[Choosing a graph](@ref "Path-complete, complete and co-complete graphs")
defines complete and co-complete graphs. `certificate(x)` evaluates ``V``.

Path-completeness turns the edge inequalities into one inequality on ``V``,
for every mode: ``V`` is a classical certificate, one function for the whole
system, though in general not one of the template.

## The three problems

Only the node conditions and the edge inequality change from one problem to
another:

| Problem | Node conditions on ``s`` | Edge inequality on ``(s, d, i)`` | Certifies |
| :-- | :-- | :-- | :-- |
| stability | ``V_s`` positive definite | ``V_d(A_i x) \le \gamma^\delta \, V_s(x)`` | ``\rho(\mathcal{A}) \le \gamma`` |
| safety | ``V_s \le 0`` on ``X_0``, ``V_s > 0`` on ``X_u`` | ``V_d(A_i x) \le V_s(x)`` | no trajectory from ``X_0`` reaches ``X_u`` |
| optimal control | ``V_s`` positive definite | ``\ell(x, K_s x) + V_d\big((A_i + B_i K_s) x\big) \le V_s(x)`` | ``J_\phi(x) \le V(x)`` for every ``x`` |

[Systems and problems](@ref) defines the joint spectral radius
``\rho(\mathcal{A})``, the sets ``X_0`` and ``X_u``, the stage cost ``\ell``
and the worst-case cost ``J_\phi``. For stability, ``\gamma`` is the rate and
``\delta`` the degree of the node functions, ``V(c x) = c^\delta V(x)`` for
``c > 0``: 2 for quadratic and piecewise quadratic functions, ``2r`` for sums
of squares, 1 for polyhedral functions. For optimal control, each node also
carries a gain ``K_s``, and the gains define the policy ``\phi`` of the
certificate.

## Quality and cost of a certificate

[`certify`](@ref) finds the best certificate on the graph by solving convex
programs built from its three arguments:

- **The template gives the variables:** the parameters of one node function,
  such as the matrix ``P`` of ``x^\top P x``.
- **The graph gives the structure:** one copy of these variables per node,
  and one edge inequality per edge.
- **The problem gives the content:** the node conditions and the edge
  inequality of the table above, the objective, and its own unknowns: the
  rate, the margin or the gains.

An edge inequality must hold for every state ``x``: it is infinitely many
constraints. The package writes it as an inclusion between sets of the node
functions (see [Conditions as set inclusions](@ref)), which SetProg.jl turns
into finitely many convex constraints on the parameters of the template. For
quadratic forms, for instance, ``V_d(A_i x) \le \gamma^2 V_s(x)`` for every
``x`` is the matrix inequality ``A_i^\top P_d A_i \preceq \gamma^2 P_s``.
These constraints decide the kind of program, linear, second-order cone or
semidefinite (see [What works with what](@ref)).

So the template and the graph influence:

- **how good the certificate can be:** it is the optimum of the program, the
  best that the functions of the template can give on the graph.
- **how much it costs to compute:** the template sets the kind of program and
  the size of each variable and constraint, and the graph sets how many there
  are.

The two pull against each other. A richer template, such as the sums of
squares of degree 4 instead of the quadratic forms (see
[Choosing a template](@ref)), or a graph with more nodes, such as a De Bruijn
graph of higher order (see [Choosing a graph](@ref)), can give a better
certificate, but builds a larger program: more variables at each node, or
more nodes and edges.

For stability on the running example, the program has one quadratic form, so
three parameters, and one ``2 \times 2`` linear matrix inequality per mode.
[`optimization_model`](@ref) builds the program without solving it.

```@setup running
using Plots
import Random

const RUNS = 100

# The level set V(x) = c of a quadratic form, one point per direction.
level_set(V, c) = [sqrt(c) .* d ./ sqrt(V(d))
                   for d in ([cos(t), sin(t)] for t in range(0, 2pi; length = 400))]

function stability_figure(certificate, A)
    fitted = only(functions(certificate))
    V(x) = node_value(get_problem(certificate), fitted, x)
    figure = plot(; aspect_ratio = :equal, framestyle = :box, legend = :outerbottom,
                  size = (520, 600))
    boundary = level_set(V, 1.0)
    plot!(figure, first.(boundary), last.(boundary); color = :black, lw = 2,
          label = "V(x) = 1")
    inner = level_set(V, certificate.rate^2)
    plot!(figure, first.(inner), last.(inner); color = :black, ls = :dash,
          label = "V(x) = γ²")
    for (i, Ai) in enumerate(A)
        image = [Ai * x for x in boundary]
        plot!(figure, first.(image), last.(image); lw = 2, label = "image by mode $i")
    end
    return figure
end

disk(radius) = Shape(radius .* cos.(range(0, 2pi; length = 200)),
                     radius .* sin.(range(0, 2pi; length = 200)))

function safety_figure(certificate, system)
    rng = Random.MersenneTwister(1)
    figure = plot(; aspect_ratio = :equal, framestyle = :box, legend = :outerbottom,
                  xlims = (-6, 6), ylims = (-6, 6), size = (480, 600))
    plot!(figure, Shape([-6, 6, 6, -6], [-6, -6, 6, 6]); color = :red, alpha = 0.25,
          linealpha = 0, label = "unsafe set, ‖x‖ ≥ 5")
    plot!(figure, disk(5.0); color = :white, linecolor = :red, label = "")
    plot!(figure, disk(1.0); color = :green, alpha = 0.4, label = "initial set, ‖x‖ ≤ 1")
    for run in 1:RUNS
        angle = 2pi * run / RUNS
        xs = states(simulate(system, [cos(angle), sin(angle)], 30; rng))
        plot!(figure, first.(xs), last.(xs); color = :steelblue, alpha = 0.5,
              label = run == 1 ? "$RUNS random runs from the boundary of the initial set" : "")
    end
    grid = range(-6, 6; length = 300)
    contour!(figure, grid, grid, [certificate([x, y]) for y in grid, x in grid];
             levels = [0.0], color = :black, lw = 2, colorbar = false)
    # `contour!` adds no legend entry of its own.
    plot!(figure, [NaN], [NaN]; color = :black, lw = 2, label = "V(x) = 0")
    return figure
end

function control_figure(certificate, Q, R, x0)
    rng = Random.MersenneTwister(1)
    figure = plot(; xlabel = "step k", ylabel = "cost up to step k",
                  legend = :right, size = (700, 420))
    for run in 1:RUNS
        trajectory = simulate(certificate, x0, 50; rng)
        steps = zip(states(trajectory), inputs(trajectory))
        plot!(figure, 1:50, cumsum([x' * Q * x + u' * R * u for (x, u) in steps]);
              color = :gray, alpha = 0.3,
              label = run == 1 ? "$RUNS random sequences" : "")
    end
    hline!(figure, [certificate(x0)]; color = :black, ls = :dash, lw = 2,
           label = "certified bound")
    return figure
end
```

## Stability

The node functions form a **path-complete Lyapunov certificate**
[ahmadi2014joint](@cite). The program:

```math
\begin{aligned}
\min_{V_s,\ \gamma} \quad & \gamma \\
\text{subject to} \quad & V_d(A_i x) \le \gamma^\delta \, V_s(x) \quad \forall x
  && \text{for every edge } (s, d, i), \\
& V_s \text{ positive definite} && \text{for every node } s.
\end{aligned}
```

At a fixed rate the program is convex, so [`certify`](@ref) finds the
smallest rate by bisection:

```@example running
problem = StabilityProblem(system)
certificate = certify(template, graph, problem; optimizer = Clarabel.Optimizer)
certificate.rate
```

The rate is an upper bound on the joint spectral radius
[ahmadi2014joint; Thm. 2.4](@cite), below one, so the system is stable.

**Why it holds.** The common function satisfies
``V(A_i x) \le \gamma^\delta \, V(x)`` for every mode ``i``: it is a common
Lyapunov function, so the state shrinks at least like ``\gamma^k``, up to a
constant factor, for every switching sequence. On a complete graph, for
instance, take a node ``s`` minimizing ``V_s(x)``: the edge that leaves ``s``
with mode ``i`` ends at some node ``d``, so
``V(A_i x) \le V_d(A_i x) \le \gamma^\delta \, V_s(x) = \gamma^\delta \, V(x)``.

In a picture, the inclusion ``(A_i / \gamma) \, \Omega \subseteq \Omega`` on
the common graph: each mode maps the unit set ``\Omega`` of ``V``, bounded by
``V(x) = 1``, inside ``\gamma \, \Omega``, bounded by ``V(x) = \gamma^2``,
since ``\delta = 2`` here.

```@example running
stability_figure(certificate, [A1, A2]) # hide
```

Both images touch the dashed curve: at the smallest rate, the inequalities are
tight. [Reading a certificate](@ref) shows how to find the tight edges.

## Safety

The node functions form a **path-complete barrier certificate**
[anand2024barrier](@cite). The program:

```math
\begin{aligned}
\max_{V_s,\ \varepsilon} \quad & \varepsilon \\
\text{subject to} \quad & V_d(A_i x) \le V_s(x) \quad \forall x
  && \text{for every edge } (s, d, i), \\
& V_s \le -\varepsilon \, w \text{ on } X_0, \quad
  V_s \ge \varepsilon \, w \text{ on } X_u && \text{for every node } s, \\
& -w \le V_s \le w && \text{for every node } s.
\end{aligned}
```

A barrier changes sign, so it is not homogeneous. With the quadratic
template, it is ``V_s(x) = [x; 1]^\top P_s [x; 1]``, with ``P_s`` symmetric,
possibly indefinite. With `SumOfSquaresTemplate(r)`, it is a polynomial of
degree at most ``2r``.

The margin ``\varepsilon`` measures how well the barriers separate ``X_0``
from ``X_u``. Scaling the barriers would scale the margin, so the last
condition normalizes them, with the weight ``w(x) = (1 + \|x\|^2)^r``. This
program is that of the quadratic and sum-of-squares templates, with ``r = 1``
for quadratic forms, where the last condition is ``-I \preceq P_s \preceq I``.

The package writes the node conditions as inclusions of the zero sublevel
sets of the node functions (see [Conditions as set inclusions](@ref)), which
the S-procedure imposes. The S-procedure is sufficient, not necessary. The
polyhedral templates use second-order cone constraints instead, with a
normalization and a margin of their own, not comparable with those of the
other templates (see [What works with what](@ref)). On the running example:

```@example running
problem = SafetyProblem(system, S0, Su)
certificate = certify(template, graph, problem; optimizer = Clarabel.Optimizer)
certificate.margin
```

The margin is positive, so the system is safe.

**Why it holds.** The common function is negative on ``X_0``, positive on
``X_u``, and satisfies ``V(A_i x) \le V(x)`` for every mode ``i``: it is a
common barrier function. Along a trajectory that starts in ``X_0``, ``V``
stays negative, so the trajectory never reaches ``X_u``.

In a picture, the inclusions on the common graph: the zero sublevel set
``\Omega`` of ``V`` contains ``X_0`` and does not meet ``X_u``, and the runs
that start on the boundary of ``X_0`` never leave ``\Omega``.

```@example running
safety_figure(certificate, system) # hide
```

## Optimal control

Each node carries a positive definite node function ``V_s`` and a feedback
gain ``K_s`` [ninite2026path](@cite). The program:

```math
\begin{aligned}
\min_{V_s,\ K_s} \quad & \textstyle\sum_s \mu(V_s) \\
\text{subject to} \quad & \ell(x, K_s x) + V_d\big((A_i + B_i K_s) x\big)
  \le V_s(x) \quad \forall x && \text{for every edge } (s, d, i), \\
& V_s \text{ positive definite} && \text{for every node } s,
\end{aligned}
```

where ``\mu(V_s)`` measures the size of ``V_s``, which keeps the bound small:
``\log\det P_s`` for a quadratic form ``V_s(x) = x^\top P_s x``, and an
integral of ``V_s`` over a bounded region for the other templates.

The edge inequality is not convex in ``V_s`` and ``K_s`` together. With the
quadratic template, the change of variables to ``P_s^{-1}`` and
``K_s P_s^{-1}`` makes it a linear matrix inequality, so [`certify`](@ref)
computes both. With the other templates, the gains are fixed: by default,
[`certify`](@ref) takes those of the quadratic certificate, and its keyword
`gains`, one matrix per node, gives others. For fixed gains, the edge
inequality is convex in the node functions, as an inclusion of their unit
sets (see [Conditions as set inclusions](@ref)).

[`certify`](@ref) returns the gains, which define the **policy** of the
certificate,

```math
\phi(x) = K_{\kappa(x)} \, x, \qquad \kappa(x) \in \arg\min_{s \in S} V_s(x):
```

at each state, apply the gain of the node whose function is smallest there.
Calling the certificate at a state gives the bound on the worst-case cost of
this policy from it:

```@example running
problem = OptimalControlProblem(controlled, Q, R)
# Clarabel's chordal decomposition fails on optimal control.
optimizer = () -> Clarabel.Optimizer(chordal_decomposition_enable = false)
certificate = certify(template, graph, problem; optimizer)
certificate([1.0, 1.0])
```

From ``(1, 1)``, the policy costs at most this bound, whatever the switching.

**Why it holds.** Here the graph must be **complete**, with an edge for every
mode out of every node, which is stronger than path-complete. The common
graph is complete, with its loop for every mode. The common function is then
the minimum ``V = \min_s V_s``, and at ``x_k`` the policy applies
``u_k = K_s x_k``, with ``s = \kappa(x_k)`` attaining it. Whatever mode
occurs, an edge leaves ``s`` with it, and its inequality bounds the stage cost
by ``V(x_k) - V(x_{k+1})``. Added up, the stage costs are at most
``V(x_0)``, for every switching sequence: ``V`` bounds the worst-case cost
``J_\phi`` of the policy, and so also the robust value function ``J^\star``,
the best worst-case cost that any policy can achieve.

In a picture: the cost of the policy along 100 random sequences, from
``(1, 1)``, stays below the certified bound.

```@example running
control_figure(certificate, Q, R, [1.0, 1.0]) # hide
```

## Conditions as set inclusions

You do not need this section to use the package. It explains how the package
imposes the conditions of the three problems, and what a new template must
support (see [Extending the package](@ref)).

The package does not impose the conditions of a problem as inequalities
between functions. It writes each one as an inclusion between sets of the
node functions, and SetProg.jl reformulates the inclusion for each template
[legat2023computation](@cite). A problem is therefore written once, for every
template whose inclusions SetProg.jl supports.

Three notions turn inequalities into inclusions:

- **The unit set.** A function ``V``, nonnegative and positively homogeneous
  of degree ``\delta``, is determined by its unit set
  ``\Omega = \{x : V(x) \le 1\}``: ``V(x) = g_\Omega(x)^\delta``, with
  ``g_\Omega`` the gauge of ``\Omega`` (see [Systems and problems](@ref)).
  Two such functions satisfy ``V(x) \ge W(x)`` for every ``x`` exactly when
  the unit set of ``V`` is contained in that of ``W``.
- **The preimage.** ``A^{-1} \Omega = \{x : A x \in \Omega\}`` is the unit set
  of ``V(A x)``, for any matrix ``A``.
- **The polar.** For a closed convex set ``C`` containing the origin,
  ``C^\circ = \{y : y^\top x \le 1 \text{ for all } x \in C\}``. It reverses
  inclusions, ``C \subseteq D`` exactly when ``D^\circ \subseteq C^\circ``, so
  SetProg.jl can impose an inclusion on the sets or on their polars, whichever
  keeps the template tractable.

Each problem then reads:

| Problem | Set ``\Omega_s`` | Inclusions | With quadratic forms |
| :-- | :-- | :-- | :-- |
| stability | ``\{x : V_s(x) \le 1\}`` | ``(A_i / \gamma) \, \Omega_s \subseteq \Omega_d`` | ``\gamma^2 P_s - A_i^\top P_d A_i \succeq 0`` |
| safety | ``\{x : V_s(x) \le 0\}`` | ``X_0 \subseteq \Omega_s``, ``\Omega_s \cap X_u = \emptyset``, ``A_i \Omega_s \subseteq \Omega_d`` | the S-procedure in ``[x; 1]`` |
| optimal control | ``\{x : V_s(x) \le 1\}`` | ``\Omega_s \subseteq (A_i + B_i K_s)^{-1} \Omega_d \mathbin{\hat{+}_\delta} \mathcal{Q} \mathbin{\hat{+}_\delta} K_s^{-1} \mathcal{R}`` | ``P_s \succeq Q + K_s^\top R K_s + (A_i + B_i K_s)^\top P_d (A_i + B_i K_s)`` |

- **Stability.** The edge inequality reads
  ``V_d\big((A_i / \gamma) x\big) \le V_s(x)``, so the unit set of ``V_s`` is
  in the preimage of ``\Omega_d`` by ``A_i / \gamma``. For quadratic forms,
  the unit sets are ellipsoids, and the inclusion is a matrix inequality.
- **Safety.** A barrier is not homogeneous, and only its sign matters, so
  ``\Omega_s`` is its zero sublevel set. The first two inclusions are the node
  conditions, and the edge inequality implies the third. Together they prove
  safety: along a path of the graph, a trajectory from ``X_0`` stays in the
  sets ``\Omega_s``, which do not meet ``X_u``.
- **Optimal control.** With the cost
  ``\ell(x, u) = g_{\mathcal Q}(x)^p + g_{\mathcal R}(u)^p`` of
  [Systems and problems](@ref) and node functions of the same degree
  ``\delta = p``, the right side of the edge inequality is a sum of
  ``\delta``-th powers of gauges: of ``\mathcal Q``, of
  ``K_s^{-1} \mathcal R`` and of ``(A_i + B_i K_s)^{-1} \Omega_d``, all at
  ``x``. For closed convex sets ``C`` and ``D`` containing the origin and
  ``\delta \ge 1``, the **polar ``L_\delta`` sum**
  ``C \mathbin{\hat{+}_\delta} D`` is the set whose gauge ``g`` satisfies
  ``g^\delta = g_C^\delta + g_D^\delta`` [gardner2013operations](@cite). So,
  for convex node functions, the edge inequality is the inclusion of the
  table. For fixed gains, it is convex in the sets ``\Omega_s``. For
  ellipsoids, the polar ``L_2`` sum adds the matrices.

## Next

The template and the graph are your two choices: see
[Choosing a template](@ref) and [Choosing a graph](@ref). Then
[Reading a certificate](@ref) explains what [`certify`](@ref) returns. Not
every combination is supported: see [What works with what](@ref).
