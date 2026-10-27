```@meta
CurrentModule = PathCompleteCertificates
```

# Systems and problems

Part I of the manual follows one running example from start to end. This page
defines switched linear systems and the three problems the package certifies,
and shows why simulations cannot answer them. The next page certifies the
three problems on the running example; the pages after it choose the template
and the graph for stability, and read the three certificates.

## Switched linear systems

The state ``x_k \in \mathbb{R}^n`` evolves in discrete time, and at each step
the mode ``\sigma(k) \in \{1, \dots, M\}`` selects the dynamics.

### Autonomous systems

```math
x_{k+1} = A_{\sigma(k)} x_k,
```

with one matrix ``A_i \in \mathbb{R}^{n \times n}`` per mode.
[`switched_system`](@ref) builds the system from its matrices:

```@example running
import PathCompleteCertificates as PCC

A1 = [0.1552 0.0447; 0.7641 0.7472]
A2 = [0.0475 0.9176; 0.1896 0.0185]
system = PCC.switched_system([A1, A2])
PCC.n_modes(system), PCC.has_input(system)
```

### Controlled systems

```math
x_{k+1} = A_{\sigma(k)} x_k + B_{\sigma(k)} u_k,
```

with, in addition, one matrix ``B_i \in \mathbb{R}^{n \times m}`` per mode and
the input ``u_k \in \mathbb{R}^m``. [`switched_system`](@ref) takes the ``B_i``
as a second argument:

```@example running
B1 = [1.0; 0.0;;]
B2 = [1.0; 0.0;;]
controlled = PCC.switched_system([A1, A2], [B1, B2])
PCC.n_modes(controlled), PCC.has_input(controlled)
```

[`state_matrices`](@ref) and [`input_matrices`](@ref) return the matrices.

### Arbitrary switching

The modes ``\sigma(0), \sigma(1), \dots`` are not chosen by you: any sequence
may occur, and a certificate must hold for all of them. In a controlled
system, the controller chooses the input, not the mode. Switching restricted
by an automaton is planned: see
[issue #45](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues/45).

## Simulating a run

[`simulate`](@ref) runs a system from an initial state along a sequence of
modes, or along random modes when given a number of steps, and returns a
[`Trajectory`](@ref). Here the system runs from ``x_0 = (1, 1)`` along the
modes ``1, 2, 2, 1``, and [`states`](@ref) returns the state trajectory,
``x_0`` to ``x_4``:

```@example running
trajectory = PCC.simulate(system, [1.0, 1.0], [1, 2, 2, 1])
PCC.states(trajectory)
```

A controlled system also needs its inputs, as a vector of inputs or as a
feedback law `u(x)`, here ``u(x) = -0.5 x_1``:

```@example running
trajectory = PCC.simulate(controlled, [1.0, 1.0], [1, 2, 2, 1]; u = x -> [-0.5 * x[1]])
PCC.states(trajectory)
```

[`switching`](@ref) and [`inputs`](@ref) return the modes and the inputs of a
trajectory. With Plots loaded, `plot(trajectory)` draws it.

**A run shows one behavior of the system and proves nothing about the
others,** as the next section shows.

## What can be certified

Each of the three properties is a problem, built from the system. Simulations
cannot prove any of them, and a figure for each problem shows why, on a small system that
is fragile under switching:

```@example running
M1 = [0.1 1.25; 0.0 0.1]
M2 = [0.1 0.0; 1.25 0.1]
fragile = PCC.switched_system([M1, M2])
nothing # hide
```

Each mode alone is stable, with spectral radius ``0.1``, but alternating the
two makes the state grow by about ``1.26`` per step, the square root of the
spectral radius of ``M_1 M_2``. Random sequences rarely alternate for long, so
simulations miss it: of the ``2^{50}`` sequences of 50 modes, they try a few.
A certificate holds for all of them.

```@setup running
using Plots
import LinearAlgebra
import Random

const RUNS = 100

random_label(run) = run == 1 ? "$RUNS random sequences" : ""

function stability_figure(system)
    rng = Random.MersenneTwister(1)
    figure = plot(; yscale = :log10, xlabel = "step k", ylabel = "‖xₖ‖",
                  legend = :bottomleft, size = (700, 420))
    for run in 1:RUNS
        states = PCC.states(PCC.simulate(system, [1.0, 1.0], 50; rng))
        plot!(figure, 0:50, LinearAlgebra.norm.(states); color = :gray, alpha = 0.3,
              label = random_label(run))
    end
    states = PCC.states(PCC.simulate(system, [1.0, 1.0], repeat([1, 2], 25)))
    plot!(figure, 0:50, LinearAlgebra.norm.(states); color = :red, lw = 2,
          label = "1, 2, 1, 2, …")
    return figure
end

disk(radius) = Shape(radius .* cos.(range(0, 2pi; length = 200)),
                     radius .* sin.(range(0, 2pi; length = 200)))

function safety_figure(system)
    rng = Random.MersenneTwister(1)
    figure = plot(; aspect_ratio = :equal, framestyle = :box, legend = :outerbottom,
                  xlims = (-7, 7), ylims = (-7, 7), size = (480, 560))
    plot!(figure, Shape([-7, 7, 7, -7], [-7, -7, 7, 7]); color = :red, alpha = 0.25,
          linealpha = 0, label = "unsafe set, ‖x‖ ≥ 5")
    plot!(figure, disk(5.0); color = :white, linecolor = :red, label = "")
    plot!(figure, disk(1.0); color = :green, alpha = 0.4, label = "initial set, ‖x‖ ≤ 1")
    for run in 1:RUNS
        angle = 2pi * rand(rng)
        x0 = sqrt(rand(rng)) .* [cos(angle), sin(angle)]
        states = PCC.states(PCC.simulate(system, x0, 50; rng))
        plot!(figure, first.(states), last.(states); color = :gray, alpha = 0.4,
              label = random_label(run))
    end
    states = PCC.states(PCC.simulate(system, [0.0, 1.0], repeat([1, 2], 4)))
    plot!(figure, first.(states), last.(states); color = :red, lw = 2, marker = :circle,
          label = "1, 2, 1, 2, …")
    return figure
end

# The gain of the linear-quadratic regulator of one mode, by value iteration.
function regulator(A, B, Q, R)
    P = Q
    for _ in 1:1000
        P = Q + A' * P * A - A' * P * B * ((R + B' * P * B) \ (B' * P * A))
    end
    return -((R + B' * P * B) \ (B' * P * A))
end

function control_figure(A, B, Q, R)
    gain = regulator(A[1], B, Q, R)  # one gain, whatever the mode
    function cost(modes)
        x = [1.0, 1.0]
        total = [0.0]
        for i in modes
            u = gain * x
            push!(total, last(total) + x' * Q * x + u' * R * u)
            x = A[i] * x + B * u
        end
        return total
    end
    rng = Random.MersenneTwister(1)
    figure = plot(; yscale = :log10, xlabel = "step k", ylabel = "cost up to step k",
                  legend = :topleft, size = (700, 420))
    for run in 1:RUNS
        plot!(figure, 1:50, cost(rand(rng, 1:2, 50))[2:end]; color = :gray, alpha = 0.3,
              label = random_label(run))
    end
    plot!(figure, 1:50, cost(repeat([1, 2], 25))[2:end]; color = :red, lw = 2,
          label = "1, 2, 1, 2, …")
    return figure
end
```

### Stability

The joint spectral radius of the matrices,

```math
\rho = \lim_{k \to \infty} \max_{i_1, \dots, i_k}
\| A_{i_k} \cdots A_{i_1} \|^{1/k},
```

is the worst asymptotic growth rate of the trajectories. An autonomous system
is asymptotically stable under arbitrary switching exactly when ``\rho < 1``.
A stability certificate gives an upper bound on ``\rho``.

On the fragile system, every random run shrinks, yet the alternating sequence
grows without bound: ``\rho \ge 1.26``.

```@example running
stability_figure(fragile) # hide
```

For the running example:

```@example running
stability = PCC.StabilityProblem(system)
nothing # hide
```

A complete example: [Bound the joint spectral radius of my system](@ref).

### Safety

Given an initial set and an unsafe set, a safety certificate proves that no
trajectory of an autonomous system starting in the first ever reaches the
second, whatever the switching.

On the fragile system, with the initial set ``\|x\| \le 1`` and the unsafe set
``\|x\| \ge 5``, every random run stays safe, yet the alternating sequence
from ``(0, 1)`` reaches the unsafe set in eight steps.

```@example running
safety_figure(fragile) # hide
```

For the running example, with the same sets, given in homogeneous coordinates
as ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``:

```@example running
S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 1.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -25.0]
safety = PCC.SafetyProblem(system, S0, Su)
nothing # hide
```

A complete example: [Prove my system safe](@ref).

### Optimal control

Given a controlled system and the stage cost ``x_k^\top Q x_k + u_k^\top R u_k``,
with ``Q`` and ``R`` positive definite, an optimal control certificate gives a
state-feedback policy ``u_k = \phi(x_k)``, a function of the state only, and
an upper bound on its total cost
``\sum_{k \ge 0} x_k^\top Q x_k + u_k^\top R u_k`` from each initial state,
for every switching sequence.

On the fragile system with the input matrix ``B = (-0.6, 0.8)`` in both
modes, and ``Q = I``, ``R = 1``, take the policy ``u = K x``, with ``K`` the
gain of the linear-quadratic regulator designed for mode 1. The closed loop of
each mode is stable,
and every random run has a small cost, yet along the alternating sequence the
closed loop grows by about ``1.23`` per step, and the cost grows without
bound.

```@example running
control_figure([M1, M2], [-0.6; 0.8;;], [1.0 0.0; 0.0 1.0], [1.0;;]) # hide
```

For the running example:

```@example running
Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]
control = PCC.OptimalControlProblem(controlled, Q, R)
nothing # hide
```

A complete example: [Design a controller robust to switching](@ref).
