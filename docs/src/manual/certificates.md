```@meta
CurrentModule = PathCompleteCertificates
```

# How a certificate works

```@setup running
import PathCompleteCertificates as PCC
import Clarabel
import JuMP
A1 = [0.1552 0.0447; 0.7641 0.7472]
A2 = [0.0475 0.9176; 0.1896 0.0185]
system = PCC.switched_system([A1, A2])
controlled = PCC.switched_system([A1, A2], [[1.0; 0.0;;], [1.0; 0.0;;]])
S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 1.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -25.0]
Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]
```

A certificate has three ingredients: a template, a graph, and one inequality
per edge of the graph, set by the problem. Only the inequality changes from
one problem to the next: this page certifies the three problems of the
running example with the same template and graph, and explains why each
certificate holds for every switching sequence.

The code on this page uses the running example of
[Systems and problems](@ref): `system`, `controlled`, the sets `S0` and `Su`,
and the costs `Q` and `R`, solved with Clarabel.

## The three ingredients

[`certify`](@ref) takes one argument per ingredient:
`certify(template, graph, problem)`.

### The template

The family the functions of the certificate are drawn from, called the node
functions below. Here,
[`QuadraticTemplate`](@ref) gives the quadratic forms ``V(x) = x^\top P x``,
with ``P`` positive definite.

### The graph

A directed graph whose edges carry modes: the edge ``(a, b, i)`` goes from node
``a`` to node ``b`` and reads mode ``i``. The certificate puts one function of
the template at each node ``a``, its node function ``V_a``. The graph must be
**path-complete**: every sequence of modes is read along some path of the
graph. Here, [`common_graph`](@ref) has one node and a loop per mode, so the
certificate is a single function.

```@example running
template = PCC.QuadraticTemplate()
graph = PCC.common_graph(system)
nothing # hide
```

### The edge inequality

One inequality per edge, set by the problem. The next three sections give it
for each problem, certify the running example, and explain why the
certificate holds.

```@setup running
using Plots
import Random

const RUNS = 100

# The level set V(x) = c of a quadratic form, one point per direction.
level_set(V, c) = [sqrt(c) .* d ./ sqrt(V(d))
                   for d in ([cos(t), sin(t)] for t in range(0, 2pi; length = 400))]

function stability_figure(certificate, A)
    fitted = only(PCC.functions(certificate))
    V(x) = PCC.node_value(PCC.problem(certificate), fitted, x)
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

function safety_figure(certificate)
    figure = plot(; aspect_ratio = :equal, framestyle = :box, legend = :outerbottom,
                  xlims = (-7, 7), ylims = (-7, 7), size = (480, 580))
    plot!(figure, Shape([-7, 7, 7, -7], [-7, -7, 7, 7]); color = :red, alpha = 0.25,
          linealpha = 0, label = "unsafe set, ‖x‖ ≥ 5")
    plot!(figure, disk(5.0); color = :white, linecolor = :red, label = "")
    plot!(figure, disk(1.0); color = :green, alpha = 0.4, label = "initial set, ‖x‖ ≤ 1")
    grid = range(-7, 7; length = 300)
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
        trajectory = PCC.simulate(certificate, x0, 50; rng)
        steps = zip(PCC.states(trajectory), PCC.inputs(trajectory))
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

On the edge ``(a, b, i)``:

```math
V_b(A_i x) \le \gamma^p \, V_a(x) \quad \text{for every } x,
```

where ``\gamma`` is the rate and ``p`` the degree of the template: 2 for
quadratic forms, 1 for norms. [`certify`](@ref) finds the smallest rate for
which functions satisfying every edge inequality exist:

```@example running
problem = PCC.StabilityProblem(system)
certificate = PCC.certify(template, graph, problem; optimizer = Clarabel.Optimizer)
certificate.rate
```

The rate is an upper bound on the joint spectral radius, below one, so the
system is stable.

**Why it holds.** Take a trajectory, and a path ``s_0, s_1, \dots, s_k`` that
reads its first ``k`` modes; one exists, since the graph is path-complete. At
each step ``j``, the inequality of the edge from ``s_j`` to ``s_{j+1}``
applies at ``x_j``. Chained along the path, they give
``V_{s_k}(x_k) \le \gamma^{pk} \, V_{s_0}(x_0)``: the state shrinks at least
like ``\gamma^k``, up to a constant factor, for every switching sequence.

In a picture: each mode maps the level set ``V(x) = 1`` inside the level set
``V(x) = \gamma^2``.

```@example running
stability_figure(certificate, [A1, A2]) # hide
```

Both images touch the dashed curve: at the smallest rate, the inequalities are
tight. [Reading a certificate](@ref) shows how to find the tight edges.

## Safety

On the edge ``(a, b, i)``:

```math
V_b(A_i x) \le V_a(x) \quad \text{for every } x,
```

with each ``V_a`` negative on the initial set and positive on the unsafe set.
[`certify`](@ref) maximizes the margin by which the functions separate the two
sets:

```@example running
problem = PCC.SafetyProblem(system, S0, Su)
certificate = PCC.certify(template, graph, problem; optimizer = Clarabel.Optimizer)
certificate.margin
```

The margin is positive, so the system is safe.

**Why it holds.** Take a trajectory that starts in the initial set, and a path
that reads its first ``k`` modes, as for stability. Chained along the path,
the inequalities give ``V_{s_k}(x_k) \le V_{s_0}(x_0) < 0``: the trajectory
never reaches the unsafe set, where every ``V_a`` is positive.

In a picture: the region where ``V`` is negative contains the initial set and
does not meet the unsafe set.

```@example running
safety_figure(certificate) # hide
```

## Optimal control

On the edge ``(a, b, i)``:

```math
x^\top Q x + u^\top R u + V_b(A_i x + B_i u) \le V_a(x)
\quad \text{for every } x, \text{ with } u = K_a x,
```

where the gain ``K_a`` at each node is found together with ``V_a``.
[`certify`](@ref) returns the gains, and calling the certificate at a state
gives the bound on the cost from it:

```@example running
problem = PCC.OptimalControlProblem(controlled, Q, R)
# Clarabel's chordal decomposition fails on this program, so it is turned off.
optimizer = JuMP.optimizer_with_attributes(Clarabel.Optimizer,
                                           "chordal_decomposition_enable" => false)
certificate = PCC.certify(template, graph, problem; optimizer)
certificate([1.0, 1.0])
```

From ``(1, 1)``, the policy of the certificate costs at most this bound,
whatever the switching.

**Why it holds.** Here the graph must be **complete**, with an edge for every
mode out of every node, which is stronger than path-complete; the one-node
graph is, with its loop for every mode. At each state, the policy applies the
gain of the node whose function is smallest there: ``u_k = K_s x_k``, with
``s`` minimizing ``V_s(x_k)``. Whatever mode occurs, an edge leaves ``s`` with
it, and its inequality bounds the stage cost by the decrease of
``\min_s V_s``. Added up, the stage costs are at most ``\min_s V_s(x_0)``, for
every switching sequence.

In a picture: the cost of the policy along 100 random sequences, from
``(1, 1)``, stays below the certified bound.

```@example running
control_figure(certificate, Q, R, [1.0, 1.0]) # hide
```

## Next

The template and the graph are your two choices: see
[Choosing a template](@ref) and [Choosing a graph](@ref), which also says how
a graph is checked before solving.
Then [Reading a certificate](@ref) explains what [`certify`](@ref) returns.
Not every combination is supported: see [What works with what](@ref).
