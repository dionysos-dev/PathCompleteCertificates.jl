const _SetFamily =
    Union{SetProg.AbstractVariable, AbstractVector{<:SetProg.AbstractVariable}}

"""
    is_applicable(family, system)

Whether the SetProg family applies to the system. Orthant gauges require
nonnegative dynamics.
"""
is_applicable(::SetProg.AbstractVariable, system) = true
is_applicable(::Union{SetProg.PositiveSimplex, SetProg.PositiveBox}, system) =
    is_positive(system)
is_applicable(families::AbstractVector{<:SetProg.AbstractVariable}, system) =
    all(f -> is_applicable(f, system), families)

"""
    is_closed_under(family, operation, system)

Whether a SetProg gauge family admits the operation required by a graph lift.
"""
is_closed_under(::SetProg.AbstractVariable, ::Operation, system) = false
is_closed_under(
    ::Union{SetProg.Ellipsoid, SetProg.PolySet, SetProg.PositiveSimplex},
    ::Addition,
    system,
) = true
is_closed_under(f::SetProg.Ellipsoid, ::Composition, system) =
    f.piecewise === nothing && is_invertible(system)
is_closed_under(::SetProg.PolySet, ::Composition, system) = is_invertible(system)
is_closed_under(f::SetProg.Ellipsoid, ::InverseComposition, system) =
    f.piecewise === nothing && is_invertible(system)
is_closed_under(::SetProg.PolySet, ::InverseComposition, system) = is_invertible(system)
is_closed_under(::SetProg.Polytope, ::Addition, system) = true
is_closed_under(::Union{SetProg.PositiveBox, SetProg.Parallelotope}, ::Maximum, system) =
    true
function is_closed_under(::SetProg.PositiveSimplex, ::Composition, system)
    return all(A -> all(>=(0), A) && all(>(0), sum(A; dims = 1)), mode_matrices(system))
end
function is_closed_under(::SetProg.PositiveSimplex, ::InverseComposition, system)
    return is_invertible(system) && all(A -> all(>=(0), inv(A)), mode_matrices(system))
end
function is_closed_under(
    families::AbstractVector{<:SetProg.AbstractVariable},
    operation::Operation,
    system,
)
    if operation isa Maximum && all(f -> f isa SetProg.Parallelotope, families)
        return allequal(getproperty.(families, :G))
    end
    return allequal(families) && is_closed_under(first(families), operation, system)
end

"""
    reindex(family, origins)

Follow node origins when lifting a graph. A shared family is unchanged; a
vector supplies one SetProg family per node and cannot merge unequal families.
"""
reindex(family::SetProg.AbstractVariable, ::AbstractVector) = family
reindex(families::AbstractVector{<:SetProg.AbstractVariable}, origins::AbstractVector) =
    _reindexed_data(families, origins, "set families")

"""
    has_dual(family)

Whether a SetProg gauge family has an implemented dual.
"""
has_dual(family::SetProg.AbstractVariable) = SetProg.supports_dual(family)
has_dual(families::AbstractVector{<:SetProg.AbstractVariable}) = all(has_dual, families)

dual(family::SetProg.AbstractVariable) =
    has_dual(family) ? SetProg.dual_family(family) :
    throw(ArgumentError("no dual gauge family is implemented for $(typeof(family))"))
dual(families::AbstractVector{<:SetProg.AbstractVariable}) = dual.(families)

"""
    dual(family, set)

The fitted dual homogeneous gauge as a SetProg set.
"""
dual(family::SetProg.AbstractVariable, set) =
    has_dual(family) ? SetProg.dual_value(set) :
    throw(ArgumentError("no dual gauge is implemented for $(typeof(family))"))
dual(families::AbstractVector{<:SetProg.AbstractVariable}, set) = SetProg.dual_value(set)

function _prepared_families(family::_SetFamily, dimension, count)
    families = family isa AbstractVector ? family : fill(family, count)
    length(families) == count || throw(ArgumentError("one set family is required per node"))
    polynomials = filter(f -> f isa SetProg.PolySet, families)
    x = nothing
    if !isempty(polynomials)
        explicit = [f.variables for f in polynomials if f.variables !== nothing]
        x = isempty(explicit) ? SetProg.new_polyvars(dimension) : first(explicit)
        all(==(x), explicit) ||
            throw(ArgumentError("polynomial sets must share their variables"))
    end
    return [SetProg.with_dimension(f, dimension; variables = x) for f in families]
end

function homogeneity_degree(family::_SetFamily)
    return SetProg.homogeneity_degree(family)
end
function add_function_variables!(model, family::SetProg.AbstractVariable, dimension, node)
    return SetProg.add_function_variables!(model, family, dimension, node)
end
function add_normalization!(model, family::SetProg.AbstractVariable, V; kwargs...)
    return SetProg.add_normalization!(model, family, V; kwargs...)
end
function add_decrease!(
    model,
    family::SetProg.AbstractVariable,
    source,
    destination,
    A;
    kwargs...,
)
    return SetProg.add_decrease!(model, family, source, destination, A; kwargs...)
end
function solution_value(family::SetProg.AbstractVariable, V)
    return SetProg.solution_value(family, V)
end
function decrease_slack(family::SetProg.AbstractVariable, source, destination, A; kwargs...)
    return SetProg.decrease_slack(family, source, destination, A; kwargs...)
end

node_value(::_SetFamily, ::AbstractProblem, V, x::AbstractVector{<:Real}) = V(x)
