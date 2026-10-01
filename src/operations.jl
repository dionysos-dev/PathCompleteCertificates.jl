# The vocabulary templates and lifts share. A template declares which of these
# it is closed under; a lift names which it combines node functions with. Neither
# owns the words, so they sit at the top level like `aggregation.jl`.

"""
    Operation

An operation on node functions that a template may be closed under, and that a
lift may require (Debauche, Della Rossa & Jungers, Def. 7).

The inhabitants are [`Addition`](@ref), [`Maximum`](@ref), [`Minimum`](@ref),
[`Composition`](@ref) and [`InverseComposition`](@ref). A template answers
[`is_closed_under`](@ref) for each; a lift lists its [`requirements`](@ref);
[`is_valid`](@ref) is written once against the two.
"""
abstract type Operation end

"""
    Addition()

Pointwise addition of node functions: the operation behind [`SumLift`](@ref).
"""
struct Addition <: Operation end

"""
    Maximum()

Pointwise maximum of node functions: the operation behind [`MaxLift`](@ref).
"""
struct Maximum <: Operation end

"""
    Minimum()

Pointwise minimum of node functions: the operation behind [`MinLift`](@ref).
"""
struct Minimum <: Operation end

"""
    Composition()

Composition with the dynamics, `V ∘ A_i`: the operation behind
[`CompositionLift`](@ref).
"""
struct Composition <: Operation end

"""
    InverseComposition()

Composition with the inverse dynamics, `V ∘ A_i⁻¹`: the operation behind the
backward composition lift, `dual(CompositionLift(T))`.
"""
struct InverseComposition <: Operation end

"""
    dual(x)

The dual of a graph, a lift, an operation, a template, a system, a problem or a
certificate; `dual(template, V)` is the dual of one node function.

Duality is an involution on the whole problem: a certificate on `graph` for
`template` and `system` is one on `dual(graph)` for `dual(template)` and
`dual(system)` (Debauche, Lemma 6.25), and `dual(certificate)` constructs it.
On an operation it is the correspondence of Lemma 1.27: minimum and maximum
exchange, addition is fixed, composition becomes composition with the inverse.
"""
function dual end

dual(::Addition) = Addition()
dual(::Maximum) = Minimum()
dual(::Minimum) = Maximum()
dual(::Composition) = InverseComposition()
dual(::InverseComposition) = Composition()
