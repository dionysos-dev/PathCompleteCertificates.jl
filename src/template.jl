import JuMP
import LinearAlgebra

"""
    AbstractTemplate

Abstract supertype for families of candidate Lyapunov functions.
"""
abstract type AbstractTemplate end

raw"""
    LinearCopositiveTemplate

The template ``V(x) = c^\top x`` on the nonnegative orthant.  It is applicable
to positive switched systems only: every mode matrix must map ``\mathbb{R}^n_+``
into itself.
"""
struct LinearCopositiveTemplate <: AbstractTemplate end

raw"""
    QuadraticTemplate

The template ``V(x) = x^\top P x``, with ``P`` positive definite.
"""
struct QuadraticTemplate <: AbstractTemplate end

"""
    add_function_variables!(model, template, dimension, node)

Add the decision variables representing one candidate function at `node` and
return them.  `node` is used solely to give variables distinct names.
"""
function add_function_variables! end

"""
    add_nonnegativity!(model, V)

Constrain the candidate function `V` to be nonnegative.  Strict positivity is
added separately by the stability problem's normalization.
"""
function add_nonnegativity! end

function add_function_variables!(
    model::JuMP.Model,
    ::Type{LinearCopositiveTemplate},
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return JuMP.@variable(model, [1:dimension], base_name = "c_$(node)")
end

function add_nonnegativity!(model::JuMP.Model, c::AbstractVector)
    JuMP.@constraint(model, c .>= 0)
    return nothing
end

function add_function_variables!(
    model::JuMP.Model,
    ::Type{QuadraticTemplate},
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return JuMP.@variable(model, [1:dimension, 1:dimension], PSD, base_name = "P_$(node)",)
end

function add_nonnegativity!(model::JuMP.Model, P::LinearAlgebra.Symmetric)
    # `PSD` in add_function_variables! already imposes this constraint.
    return nothing
end
