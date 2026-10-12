# Operations on node functions, shared by templates and lifts.

"""
    Operation

An operation on node functions that a template may be closed under
([`is_closed_under`](@ref)) and a lift may require ([`requirements`](@ref)).
"""
abstract type Operation end

"""
    Addition()

Pointwise addition of node functions, required by [`SumLift`](@ref).
"""
struct Addition <: Operation end

"""
    Maximum()

Pointwise maximum of node functions, required by [`MaxLift`](@ref).
"""
struct Maximum <: Operation end

"""
    Minimum()

Pointwise minimum of node functions, required by [`MinLift`](@ref).
"""
struct Minimum <: Operation end

"""
    Composition()

Composition with the dynamics, `V ∘ A_i`, required by [`CompositionLift`](@ref).
"""
struct Composition <: Operation end

"""
    InverseComposition()

Composition with the inverse dynamics, `V ∘ A_i⁻¹`, required by
[`BackwardCompositionLift`](@ref).
"""
struct InverseComposition <: Operation end

"""
    dual(x)

The dual of a graph, lift, operation, template, system, problem or certificate;
`dual(template, V)` is the dual of one node function.
"""
function dual end

dual(::Addition) = Addition()
dual(::Maximum) = Minimum()
dual(::Minimum) = Maximum()
dual(::Composition) = InverseComposition()
dual(::InverseComposition) = Composition()
