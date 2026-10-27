```@meta
CurrentModule = PathCompleteCertificates
```

# Reading a certificate

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
template = PCC.QuadraticTemplate()
graph = PCC.common_graph(system)
lyapunov = PCC.certify(template, graph, PCC.StabilityProblem(system);
                       optimizer = Clarabel.Optimizer)
barrier = PCC.certify(template, graph, PCC.SafetyProblem(system, S0, Su);
                      optimizer = Clarabel.Optimizer)
optimizer = JuMP.optimizer_with_attributes(Clarabel.Optimizer,
                                           "chordal_decomposition_enable" => false)
controller = PCC.certify(template, graph, PCC.OptimalControlProblem(controlled, Q, R);
                         optimizer)
```

[`certify`](@ref) returns a certificate. This page shows what every certificate
holds, then what is specific to each problem.

The code on this page uses the three certificates of
[How a certificate works](@ref), on the one-node graph with the quadratic
template: `lyapunov` for stability, `barrier` for safety, and `controller` for
optimal control.

## Feasible or not

Check [`is_feasible`](@ref) first:

```@example running
PCC.is_feasible(lyapunov), PCC.is_feasible(barrier), PCC.is_feasible(controller)
```

An infeasible result means that no certificate was found with this template on
this graph, not that the property fails: try another template or another
graph. [`status`](@ref) gives the solver's termination status, for diagnosis.

## What every certificate holds

| | |
| :-- | :-- |
| [`functions`](@ref)`(c)` | the node functions, one per node; for stability, fitted SetProg sets, evaluated with [`node_value`](@ref) |
| [`graph`](@ref)`(c)` | the graph of the certificate |
| [`template`](@ref)`(c)` | the template of its node functions |
| [`problem`](@ref)`(c)` | the problem it certifies |
| [`status`](@ref)`(c)` | the termination status of the solver |

## The common function

The node functions combine into one function of the state, the common
function. Calling the certificate evaluates it:

| Certificate | ``c(x)`` |
| :-- | :-- |
| stability | the common Lyapunov function |
| safety | the common barrier, negative on a region that contains the initial set, is invariant, and avoids the unsafe set |
| optimal control | a bound on the cost of the policy from ``x`` |

```@example running
x = [1.0, 0.0]
lyapunov(x), barrier(x), controller(x)
```

## Tight edges

An edge is **tight** when its inequality is active, with zero slack.
[`edge_slacks`](@ref) measures every edge, and [`tight_edges`](@ref) lists
those whose slack is at most `atol`, ``10^{-4}`` by default:

```@example running
PCC.edge_slacks(lyapunov), PCC.edge_slacks(barrier), PCC.edge_slacks(controller)
```

Both edges are tight for stability and for safety; the inequalities of the
controller have slack. Tight edges are what [Refining the graph](@ref) reads to
grow the graph.

[`certify`](@ref) stops within `rtol` of the smallest rate, so the slacks of a
stability certificate are of that order. Read them with an `atol` at least
ten times `rtol`: the defaults, `rtol = 1e-6` and `atol = 1e-4`, satisfy it,
and a certificate computed with a coarser `rtol` needs a larger `atol`.

## Stability

### The rate, smallest or given

`c.rate` is an upper bound on the joint spectral radius. Given a `rate`,
[`certify`](@ref) solves at that rate only, and [`is_feasible`](@ref) says
whether it is certified:

```@example running
at(rate) = PCC.certify(template, graph, PCC.StabilityProblem(system);
                       optimizer = Clarabel.Optimizer, rate)
lyapunov.rate, PCC.is_feasible(at(0.95)), PCC.is_feasible(at(1.0))
```

### A lower bound, and exactness

[`jsr_lower_bound`](@ref) gives a lower bound on the joint spectral radius,
from the cycles of tight edges, and [`optimality_gap`](@ref) is the rate minus
it. [`is_jsr_exact`](@ref) tests a condition under which the rate equals the
joint spectral radius; `false` means unknown:

```@example running
PCC.jsr_lower_bound(lyapunov), PCC.optimality_gap(lyapunov), PCC.is_jsr_exact(lyapunov)
```

The joint spectral radius of the running example therefore lies between the
lower bound and the rate. A better graph lowers the rate: see
[Choosing a graph](@ref).

### The dual certificate

[`dual`](@ref)`(c)` gives a certificate on the dual graph, for the transposed
system, at the same rate, without solving anything: see [Duality](@ref).

A complete example: [Bound the joint spectral radius of my system](@ref).

## Safety

`c.margin` is the margin by which the barrier separates the initial set from
the unsafe set, positive when safety is certified:

```@example running
barrier.margin
```

`c.initial_multipliers` and `c.unsafe_multipliers` hold the multipliers of the
two sets, one per node.

A complete example: [Prove my system safe](@ref).

## Optimal control

`c.gains` holds one gain per node:

```@example running
controller.gains
```

At each state, the policy applies the gain of the node whose function is
smallest there, and [`simulate`](@ref)`(c, x0, modes)` runs it; the inputs it
applied:

```@example running
trajectory = PCC.simulate(controller, [1.0, 1.0], [1, 2, 2, 1])
PCC.inputs(trajectory)
```

A complete example: [Design a controller robust to switching](@ref).
