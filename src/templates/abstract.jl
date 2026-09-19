import JuMP
import LinearAlgebra

"""
    AbstractTemplate

A family of candidate node functions.

A template supplies primitives; a problem chooses which to apply. It is passed
as an **instance**, not a type, because a template need not be determined by its
type — [`PolyhedralTemplate`](@ref) carries one fixed matrix per node.
"""
abstract type AbstractTemplate end

"""
    rate_exponent(template) -> Int

The degree of homogeneity of the template's functions, `V(cx) = cᵈ V(x)`.

The edge condition is `V_dst(Ax) ≤ γᵈ V_src(x)`, so this is what makes `γ` mean
a contraction rate for every template. Quadratic forms are degree 2, linear
functionals and norms degree 1.
"""
function rate_exponent end

"""
    add_function_variables!(model, template, dimension, node)

Add the decision variables for one candidate function at `node` and return it.

`node` selects that node's fixed template data, where the template has any.
"""
function add_function_variables! end

"""
    add_nonnegativity!(model, template, V)

Constrain `V` to be nonnegative.

Dispatch is on the template, not on the type of `V`: two templates may represent
their functions with the same container, and dispatching on the container then
applies the wrong constraint silently.
"""
function add_nonnegativity! end

"""
    add_normalization!(model, template, V)

Rule out the degenerate member of the family, typically `V ≡ 0` — which
satisfies every homogeneous edge condition and certifies nothing.

Separate from [`add_nonnegativity!`](@ref) because a problem may want one
without the other: safety's barriers are sign-free but still must not vanish.
"""
function add_normalization! end

"""
    add_domination!(model, template, V_src, V_dst, map; scale = 1, margin = 0)

Constrain, for every ``x``,

```math
\\text{scale} \\cdot V_{src}(x) - V_{dst}(\\text{map} \\cdot x)
    - \\text{margin}\\,\\|x\\|^d \\ge 0,
```

where ``d`` is [`rate_exponent`](@ref). `scale` and `margin` may be JuMP
expressions.

Quantifying over all `x` needs a lifting into a cone, which is template-specific
but problem-agnostic — so this is the method that keeps the interface at
templates + problems rather than templates × problems. A template that cannot
express `margin` should accept `margin = 0` and throw otherwise.
"""
function add_domination! end

"""
    solution_value(template, V)

The fitted node function after `optimize!`: the same object holding numbers
rather than variables.

Not a plain `JuMP.value` broadcast, because a node function may carry fixed data
alongside its variables — a [`PolyhedralFunction`](@ref) keeps its `G`.
"""
function solution_value end

"""
    check_dynamics(template, A)

Throw if `template` does not apply to the mode matrices `A`.

A copositive function certifies nothing about a system that leaves the
nonnegative orthant. The default is that every template applies.
"""
function check_dynamics end

check_dynamics(::AbstractTemplate, ::AbstractVector{<:AbstractMatrix}) = nothing
