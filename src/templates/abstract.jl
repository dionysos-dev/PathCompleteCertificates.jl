import JuMP
import LinearAlgebra

"""
    AbstractTemplate

Abstract supertype for families of candidate functions.

**A template supplies primitives; a problem chooses which to apply.** That is
the whole interface, and it is why a template is added by adding one file here
and nothing else: `add_domination!` states one function dominates another under
an affine map, `add_nonnegativity!` and `_add_normalization!` state a function
is a usable member of the family, and the rest is bookkeeping. Stability applies
all of them; safety applies only domination, because its barriers are sign-free.
Nothing in this directory knows what a problem is.

A template is passed as an **instance**, not as a type. `QuadraticTemplate()`
and `LinearCopositiveTemplate()` are singletons carrying nothing, but a
template is not in general determined by its type: [`PolyhedralTemplate`](@ref)
carries one fixed matrix per node, and there is nowhere to put that on a
`::Type{T}` argument.
"""
abstract type AbstractTemplate end

"""
    rate_exponent(template) -> Int

The degree of homogeneity of the template's functions: `V(cx) = c^d V(x)`.

The edge condition is `V_dst(A x) <= gamma^d V_src(x)`, so this is what makes
the `gamma` a driver bisects on mean the same thing for every template — a
contraction rate, and hence a joint-spectral-radius bound. A quadratic form is
degree 2; a linear functional and a norm are degree 1.
"""
function rate_exponent end

"""
    add_function_variables!(model, template, dimension, node)

Add the decision variables representing one candidate function at `node` and
return it.  `node` selects the node's fixed template data, where the template
has any, and names the variables.
"""
function add_function_variables! end

"""
    add_nonnegativity!(model, template, V)

Constrain the candidate function `V` to be nonnegative.  Strict positivity is
added separately by the stability problem's normalization.

Dispatch is on the *template*, not on the type of `V`: two templates can
perfectly well represent their functions with the same container, and then
dispatching on the container silently applies the wrong constraint.
"""
function add_nonnegativity! end

"""
    _add_normalization!(model, template, V)

Rule out the degenerate member of the family — typically `V ≡ 0`, which
satisfies every homogeneous edge condition and certifies nothing.

Separate from [`add_nonnegativity!`](@ref) because a problem may want one
without the other, and because what counts as degenerate is the template's
business: a floor on the weights for a polyhedral function, `P ⪰ I` for a
quadratic one.
"""
function _add_normalization! end

"""
    add_domination!(model, template, V_src, V_dst, map; scale = 1, margin = 0)

Constrain, for every ``x``,

```math
\\text{scale} \\cdot V_{src}(x) \\;-\\; V_{dst}(\\text{map} \\cdot x)
    \\;-\\; \\text{margin}\\,\\|x\\|^d \\;\\ge\\; 0,
```

where ``d`` is [`rate_exponent`](@ref). `scale` and `margin` may be JuMP
expressions.

**This is the method that stops the interface scaling as templates × problems.**
Quantifying over all `x` needs a lifting into a cone, and that lifting is
template-specific — which is why it cannot be written once against a callable
`V(x)`. But it is *problem-agnostic*: stability is this with `scale = γ^d`,
safety is this on the homogeneous lift with `margin = ε`. So each template
writes it once, each problem calls it once, and no method is indexed by a pair.

A template that cannot express `margin` in its cone should accept `margin = 0`
and throw otherwise, rather than silently dropping it.
"""
function add_domination! end

"""
    solution_value(template, V)

The fitted node function after `optimize!`: the same object with numbers where
it held JuMP variables.

A driver cannot just broadcast `JuMP.value` over whatever
[`add_function_variables!`](@ref) returned, because a node function may carry
fixed data alongside its variables — a `PolyhedralFunction` keeps its `G`.
"""
function solution_value end

"""
    _check_dynamics(template, A)

Throw if `template` is not applicable to the mode matrices `A`.

Applicability is the template's own business — a copositive function certifies
nothing about a system that leaves the nonnegative orthant — so the check lives
with the template rather than as an `isa` test inside a problem. The default is
that every template applies.
"""
function _check_dynamics end

_check_dynamics(::AbstractTemplate, ::AbstractVector{<:AbstractMatrix}) = nothing
