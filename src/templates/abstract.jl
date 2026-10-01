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

"""
    domination_slack(template, V_src, V_dst, map; scale = 1)

How much slack the domination `scale · V_src(x) ≥ V_dst(map · x)` has, given
*fitted* node functions.

The mirror of [`add_domination!`](@ref): same arguments, same meaning, but read
off a solution rather than imposed on variables. Nonnegative when the
inequality holds, and **zero exactly when it is tight** — which is what tells
you the edge is limiting the certificate rather than slack in it.

One method per template, because the slack is in the template's own terms: the
smallest eigenvalue of a matrix pencil for a quadratic, the tightest row for a
polyhedral one.

The value is in the units of the fitted functions, and a certificate is only
determined up to scale, so compare slacks within one certificate rather than
across two.
"""
function domination_slack end

"""
    is_closed_under(template, operation, system) -> Bool

Whether the family of node functions is closed under an [`Operation`](@ref):
whether combining members of it gives a member (Debauche, Della Rossa &
Jungers, Def. 7). The template declares; the default is `false`, which claims
nothing.

`system` is read by [`Composition`](@ref) and [`InverseComposition`](@ref)
only — "closed under composition with the dynamics" is a statement about the
maps composed with — and ignored by the three pointwise operations.

What it decides is [`is_valid`](@ref): whether a lift is guaranteed not to make
the bound worse for this template. A template that is closed under nothing can
still be lifted; it just carries no such guarantee.
"""
is_closed_under(::AbstractTemplate, ::Operation, system) = false

"""
    reindex(template, origins)

The template for a lifted graph, given where each of its nodes came from — the
`origins` of a [`Lifted`](@ref).

A template that carries no per-node data returns itself. One that does, such as
[`PolyhedralTemplate`](@ref), gives every new node the data of its origin; a
node that merges several origins takes their data when it coincides and throws
otherwise.
"""
reindex(template::AbstractTemplate, ::AbstractVector) = template

# The original nodes an origin refers to, whatever a lift recorded: a copy, a
# subset, or a node paired with a word.
_origin_nodes(origin::Integer) = (origin,)
_origin_nodes(origin::AbstractVector{<:Integer}) = origin
_origin_nodes(origin::Tuple{<:Integer, <:Any}) = (first(origin),)

# One datum per new node, when its origins agree on it.
function _reindexed_data(
    data::AbstractVector,
    origins::AbstractVector,
    what::AbstractString,
)
    return map(origins) do origin
        members = _origin_nodes(origin)
        value = data[first(members)]

        all(member -> data[member] == value, members) || throw(
            ArgumentError(
                "the lift merges nodes $(collect(members)) whose $what differ; the " *
                "template carries one per node and cannot follow it",
            ),
        )

        return value
    end
end

dual(template::AbstractTemplate) =
    throw(ArgumentError("no dual template is defined for $(nameof(typeof(template)))"))
