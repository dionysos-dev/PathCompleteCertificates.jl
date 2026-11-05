```@meta
CurrentModule = PathCompleteCertificates
```

# Systems and problems

Part I of the manual follows one running example from start to end. This page
defines switched linear systems and the three problems the package certifies,
and shows why simulations cannot answer them. The next page certifies the
three problems on the running example. The pages after it choose the template
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
using PathCompleteCertificates

A1 = [0.1552 0.0447; 0.7641 0.7472]
A2 = [0.0475 0.9176; 0.1896 0.0185]
system = switched_system([A1, A2])
n_modes(system), has_input(system)
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
controlled = switched_system([A1, A2], [B1, B2])
n_modes(controlled), has_input(controlled)
```

[`state_matrices`](@ref) and [`input_matrices`](@ref) return the matrices.

### Arbitrary switching

The modes ``\sigma(0), \sigma(1), \dots`` are not chosen by you: any sequence
may occur, and a certificate must hold for all of them. In a controlled
system, the controller chooses the input, not the mode. Switching restricted
by an automaton is not supported yet (see [What works with what](@ref)).

## Simulating a run

[`simulate`](@ref) runs a system from an initial state along a sequence of
modes, or along random modes when given a number of steps, and returns a
[`Trajectory`](@ref). Here the system runs from ``x_0 = (1, 1)`` along the
modes ``1, 2, 2, 1``, and [`states`](@ref) returns the state trajectory,
``x_0`` to ``x_4``:

```@example running
trajectory = simulate(system, [1.0, 1.0], [1, 2, 2, 1])
states(trajectory)
```

A controlled system also needs its inputs, as a vector of inputs or as a
feedback law `u(x)`, here ``u(x) = -0.5 x_1``:

```@example running
trajectory = simulate(controlled, [1.0, 1.0], [1, 2, 2, 1]; u = x -> [-0.5 * x[1]])
states(trajectory)
```

[`switching`](@ref) and [`inputs`](@ref) return the modes and the inputs of a
trajectory. With Plots loaded, `plot(trajectory)` draws it.

**A run shows one behavior of the system and proves nothing about the
others,** as the next section shows.

## What can be certified

Each of the three properties is a problem, built from the system. Simulations
cannot prove any of them, and a figure for each problem shows why, on a small
example:

```@example running
M1 = [0.1 1.25; 0.0 0.1]
M2 = [0.1 0.0; 1.25 0.1]
example = switched_system([M1, M2])
nothing # hide
```

Each mode alone is stable, with spectral radius ``0.1``, but alternating the
two makes the state grow by about ``1.26`` per step, the square root of the
spectral radius of ``M_1 M_2``:

```@example running
import LinearAlgebra
spectral_radius(M) = maximum(abs, LinearAlgebra.eigvals(M))
spectral_radius(M1), spectral_radius(M2), sqrt(spectral_radius(M1 * M2))
```

Random sequences rarely alternate for long, so
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
        xs = states(simulate(system, [1.0, 1.0], 50; rng))
        plot!(figure, 0:50, LinearAlgebra.norm.(xs); color = :gray, alpha = 0.3,
              label = random_label(run))
    end
    xs = states(simulate(system, [1.0, 1.0], repeat([1, 2], 25)))
    plot!(figure, 0:50, LinearAlgebra.norm.(xs); color = :red, lw = 2,
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
        xs = states(simulate(system, x0, 50; rng))
        plot!(figure, first.(xs), last.(xs); color = :gray, alpha = 0.4,
              label = random_label(run))
    end
    xs = states(simulate(system, [0.0, 1.0], repeat([1, 2], 4)))
    plot!(figure, first.(xs), last.(xs); color = :red, lw = 2, marker = :circle,
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

The joint spectral radius of the matrices ``\mathcal{A} = \{A_1, \dots, A_M\}``,

```math
\rho(\mathcal{A}) = \lim_{k \to \infty} \max_{i_1, \dots, i_k}
\| A_{i_k} \cdots A_{i_1} \|^{1/k},
```

is the worst asymptotic growth rate of the trajectories. An autonomous system
is asymptotically stable under arbitrary switching exactly when
``\rho(\mathcal{A}) < 1``. A stability certificate gives an upper bound on
``\rho(\mathcal{A})``.

On the small example, every random run shrinks, yet the alternating sequence
grows without bound, so
``\rho(\{M_1, M_2\}) \ge \sqrt{\rho(M_1 M_2)} \approx 1.26``.

```@example running
stability_figure(example) # hide
```

For the running example:

```@example running
stability = StabilityProblem(system)
nothing # hide
```

A complete example: [Bound the joint spectral radius of my system](@ref).

### Safety

Given an initial set ``X_0`` and an unsafe set ``X_u``, a safety certificate
proves that no trajectory of an autonomous system starting in ``X_0`` ever
reaches ``X_u``, whatever the switching.

On the small example, with ``X_0 = \{x : \|x\| \le 1\}`` and
``X_u = \{x : \|x\| \ge 5\}``, every random run stays safe, yet the
alternating sequence from ``(0, 1)`` reaches ``X_u`` in eight steps.

```@example running
safety_figure(example) # hide
```

[`SafetyProblem`](@ref)`(system, S0, Su)` takes each set as one quadratic
inequality, ``\{x : [x; 1]^\top S [x; 1] \ge 0\}``, with ``S`` symmetric of
size ``n + 1``. For the running example, with the sets above,
``S_0 = \operatorname{diag}(-1, -1, 1)`` gives ``1 - \|x\|^2 \ge 0``, and
``S_u = \operatorname{diag}(1, 1, -25)`` gives ``\|x\|^2 - 25 \ge 0``:

```@example running
S0 = [-1.0 0.0 0.0; 0.0 -1.0 0.0; 0.0 0.0 1.0]
Su = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 -25.0]
safety = SafetyProblem(system, S0, Su)
nothing # hide
```

A set of another shape is given by a quadratic outer approximation, a
quadratic set that contains it. A certificate for the two larger sets also
holds for the original ones. Some templates restrict the shape of the sets
(see [What works with what](@ref)).

A complete example: [Prove my system safe](@ref).

### Optimal control

Given a controlled system and a stage cost ``\ell(x, u) \ge 0``, with
``\ell(0, 0) = 0``, the input tries to minimize the accumulated cost, while
the switching acts as an adversary. The **worst-case cost** of a
state-feedback policy ``u_k = \phi(x_k)``, a function of the state only, is

```math
J_\phi(x_0) = \sup_\sigma \sum_{k \ge 0} \ell\big(x_k, \phi(x_k)\big),
```

and the **robust value function** ``J^\star(x_0) = \inf_\phi J_\phi(x_0)`` is
the best worst-case cost that any policy can achieve. An optimal control
certificate gives a policy ``\phi`` and an upper bound on ``J_\phi``, so also
on ``J^\star``, from every initial state.

On the small example with the input matrix ``B = (-0.6, 0.8)`` in both
modes, and the cost ``\ell(x, u) = \|x\|^2 + u^2``, take the policy
``u = K x``, with ``K`` the gain of the linear-quadratic regulator designed for
mode 1. The closed loop of each mode is stable, and every random run has a
small cost, yet along the alternating sequence the state, and so the cost,
grows without bound.

```@example running
control_figure([M1, M2], [-0.6; 0.8;;], [1.0 0.0; 0.0 1.0], [1.0;;]) # hide
```

For the running example, with the quadratic cost
``\ell(x, u) = x^\top Q x + u^\top R u``, ``Q`` and ``R`` positive definite:

```@example running
Q = [1.0 0.0; 0.0 1.0]
R = [1.0;;]
control = OptimalControlProblem(controlled, Q, R)
nothing # hide
```

For a piecewise linear cost, polytopes ``\mathcal Q`` and ``\mathcal R`` of
[Polyhedra.jl](https://github.com/JuliaPolyhedra/Polyhedra.jl), bounded and
with the origin in their interior, replace the matrices. The stage cost is
then ``\ell(x, u) = g_{\mathcal Q}(x)^p + g_{\mathcal R}(u)^p``, with
``p = 1`` by default, where the **gauge**
``g_C(x) = \inf\{\lambda > 0 : x \in \lambda C\}`` of a set ``C`` is the
function equal to 1 on its boundary.

The exponent `p` must match the template (see [What works with what](@ref)).
For instance, `OptimalControlProblem(controlled, Q, R; p = 4)` gives the cost
``(x^\top Q x)^2 + (u^\top R u)^2``, for `SumOfSquaresTemplate(2; convex = true)`.

A complete example: [Design a controller robust to switching](@ref).
