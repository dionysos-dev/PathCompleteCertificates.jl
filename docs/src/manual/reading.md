```@meta
CurrentModule = PathCompleteCertificates
```

# Reading a certificate

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

[`certify`](@ref) returns a certificate. Every certificate is read in the
same way, and a few fields depend on the problem. This page shows both.

The code on this page uses the three certificates of
[How a certificate works](@ref), on the running example of
[Systems and problems](@ref), named here after what they certify:

```@example running
template = QuadraticTemplate()
graph = common_graph(system)

lyapunov = certify(template, graph, StabilityProblem(system);
                   optimizer = Clarabel.Optimizer)
barrier = certify(template, graph, SafetyProblem(system, S0, Su);
                  optimizer = Clarabel.Optimizer)
# Clarabel's chordal decomposition fails on optimal control.
optimizer = () -> Clarabel.Optimizer(chordal_decomposition_enable = false)
controller = certify(template, graph, OptimalControlProblem(controlled, Q, R);
                     optimizer)
nothing # hide
```

## Every certificate

### Feasible or not

Check [`is_feasible`](@ref) first:

```@example running
is_feasible(lyapunov), is_feasible(barrier), is_feasible(controller)
```

An infeasible result means that no certificate was found with this template on
this graph, not that the property fails: another template or another graph
may still certify it. [`status`](@ref) gives the solver's termination status,
for diagnosis.

### The node functions and the common function

| Accessor | Returns |
| :-- | :-- |
| [`functions`](@ref)`(c)` | the node functions ``V_s``, one per node |
| `c(x)` | the common function ``V`` at the state `x` |
| [`get_graph`](@ref)`(c)` | the graph of the certificate |
| [`get_template`](@ref)`(c)` | the template of its node functions |
| [`get_problem`](@ref)`(c)` | the problem it certifies |
| [`status`](@ref)`(c)` | the termination status of the solver |

[`node_value`](@ref)`(get_problem(c), V, x)` evaluates a node function `V` at
the state `x`, whatever the problem: a node function may be a SetProg set
rather than a callable. Calling the certificate at a state evaluates its common function (see
[How a certificate works](@ref)):

| Certificate | ``V(x)`` |
| :-- | :-- |
| stability | the common Lyapunov function |
| safety | the common barrier function, negative on ``X_0`` and positive on ``X_u`` |
| optimal control | an upper bound on the worst-case cost ``J_\phi(x)`` of the policy |

```@example running
x = [1.0, 0.0]
lyapunov(x), barrier(x), controller(x)
```

### Tight edges

An edge is **tight** when its edge inequality is active, with zero slack.
[`edge_slacks`](@ref) measures every edge, and [`tight_edges`](@ref) lists
those whose slack is at most `atol`, ``10^{-4}`` by default:

```@example running
edge_slacks(lyapunov), edge_slacks(barrier), edge_slacks(controller)
```

Both edges are tight for stability and for safety. For the controller, both
slacks exceed `atol`, so neither edge counts as tight. Tight edges are what
[Refining the graph](@ref) reads to grow the graph.

!!! note "Tolerances for stability"
    [`certify`](@ref) stops within `rtol` of the smallest rate, so the slacks
    of a stability certificate are of that order. Read them with an `atol` at
    least ten times `rtol`. The defaults, `rtol = 1e-6` and `atol = 1e-4`,
    satisfy it, and a certificate computed with a coarser `rtol` needs a larger
    `atol`.

## Stability

### The rate, smallest or given

`c.rate` is the rate ``\gamma``, an upper bound on the joint spectral radius.
[`certify`](@ref) finds the smallest one by bisection, up to the relative
precision `rtol`. Given a `rate`, it only checks that rate, and
[`is_feasible`](@ref) says whether it is certified: a feasible rate below one
proves stability.

```@example running
at(rate) = certify(template, graph, StabilityProblem(system);
                   optimizer = Clarabel.Optimizer, rate)
lyapunov.rate, is_feasible(at(0.95)), is_feasible(at(1.0))
```

### A lower bound, and exactness

The tight edges also bound the joint spectral radius from below:

- [`jsr_lower_bound`](@ref) is the largest ``\rho(A_w)^{1/|w|}`` over the
  words ``w`` read along the cycles of tight edges.
- [`is_jsr_exact`](@ref) holds when every node has at most one tight outgoing
  edge and the tight edges contain a cycle: the rate is then the joint
  spectral radius
  [ninite2026lifting; Thm. 4](@cite). `false` means unknown.
- [`optimality_gap`](@ref) is `0` when `is_jsr_exact` holds, and the rate
  minus the lower bound otherwise.

```@example running
jsr_lower_bound(lyapunov), is_jsr_exact(lyapunov), optimality_gap(lyapunov)
```

The joint spectral radius of the running example therefore lies between
``0.80`` and ``0.959``. Another template or another graph may lower the
rate: see [Choosing a template](@ref) and [Choosing a graph](@ref).

### The dual certificate

[`dual`](@ref)`(c)` gives a certificate on the dual graph, for the transposed
system, at the same rate, without solving anything: see [Duality](@ref).

A complete example: [Bound the joint spectral radius of my system](@ref).

## Safety

`c.margin` is the margin ``\varepsilon`` by which the barriers separate
``X_0`` from ``X_u``, positive when safety is certified:

```@example running
barrier.margin
```

`c.initial_multipliers` and `c.unsafe_multipliers` hold the multipliers of the
S-procedure for the two sets, one entry per node. With the piecewise quadratic
template, each entry holds one multiplier per cone. With the polyhedral
templates, which need none, each entry is `nothing`.

A complete example: [Prove my system safe](@ref).

## Optimal control

`c.gains` holds the gains ``K_s``, one per node:

```@example running
controller.gains
```

[`simulate`](@ref)`(c, x0, modes)` runs the closed loop of the policy of the
certificate, which applies at each state the gain of the node whose function
is smallest there, and `simulate(c, x0, n)` runs it along ``n`` random modes.
The inputs it applies along four modes:

```@example running
trajectory = simulate(controller, [1.0, 1.0], [1, 2, 2, 1])
inputs(trajectory)
```

A complete example: [Design a controller robust to switching](@ref).
