const _LinearPolytope = SetProg.Sets.Piecewise{<:Any, <:SetProg.Sets.PolarPoint}
const _LinearCopositiveSet = SetProg.Sets.Intersection{<:Any, <:SetProg.Sets.PolarPoint}

function _is_linear_copositive(::SetProg.AbstractVariable)
    return false
end
_is_linear_copositive(f::SetProg.Domain{<:SetProg.Polytope}) =
    f.set.piecewise === nothing &&
    (f.domain === SetProg.MOI.Nonnegatives || f.domain isa SetProg.MOI.Nonnegatives)

# PCC normalization policy; construction is delegated to the native family.
struct _NormalizedFamily{S <: SetProg.AbstractVariable, R} <: SetProg.AbstractVariable
    set::S
    reference::R
    contains_reference::Bool
    symmetric::Bool
    dimension::Union{Int, Nothing}
end
_NormalizedFamily(set, reference; contains_reference = true, symmetric = false) =
    _NormalizedFamily(set, reference, contains_reference, symmetric, set.dimension)
Base.:(==)(a::_NormalizedFamily, b::_NormalizedFamily) =
    a.set == b.set &&
    a.reference == b.reference &&
    a.contains_reference == b.contains_reference &&
    a.symmetric == b.symmetric
Base.hash(f::_NormalizedFamily, h::UInt) =
    hash((f.set, f.reference, f.contains_reference, f.symmetric), h)
SetProg.Sets.space_variables(f::_NormalizedFamily) = SetProg.Sets.space_variables(f.set)
SetProg.variable_polyvars(
    f::_NormalizedFamily,
    spaces::SetProg.Spaces,
    index::SetProg.SpaceIndex,
) = SetProg.variable_polyvars(f.set, spaces, index)
function SetProg.variable_set(
    model::JuMP.AbstractModel,
    f::_NormalizedFamily,
    space::SetProg.Space,
    n,
    x,
)
    return SetProg.variable_set(model, f.set, space, n, x)
end

_is_parallelotope(f) = f isa _NormalizedFamily && f.symmetric && f.set isa SetProg.Polytope

# The template primitives for SetProg families; the functions are documented in
# templates/abstract.jl.

function homogeneity_degree(::Union{SetProg.Ellipsoid, SetProg.Sets.Ellipsoid})
    return 2
end
homogeneity_degree(f::_NormalizedFamily) = homogeneity_degree(f.set)
function homogeneity_degree(
    ::Union{
        SetProg.Polytope,
        SetProg.Sets.PolarPoint,
        SetProg.Sets.Piecewise{<:Any, <:SetProg.Sets.PolarPoint},
    },
)
    return 1
end
homogeneity_degree(
    family::Union{SetProg.PolySet, SetProg.Sets.PolySet, SetProg.Sets.ConvexPolySet},
) = family.degree
homogeneity_degree(
    set::Union{SetProg.Domain, SetProg.Sets.Polar, SetProg.Sets.Intersection},
) = homogeneity_degree(set.set)
function homogeneity_degree(families::AbstractVector{<:SetProg.AbstractVariable})
    isempty(families) && throw(ArgumentError("at least one set family is required"))
    degrees = unique(homogeneity_degree.(families))
    length(degrees) == 1 ||
        throw(ArgumentError("every node must have the same gauge degree"))
    return only(degrees)
end

function _polynomial_family(f)
    return nothing
end
_polynomial_family(f::SetProg.PolySet) = f
_polynomial_family(f::_NormalizedFamily{<:SetProg.PolySet}) = f.set

# Fill the dimension of a homogeneous gauge family, validating explicit data.
# `variables` supplies a shared polynomial coordinate system when needed.
function _with_dimension(family::SetProg.AbstractVariable, n::Integer; variables = nothing)
    n > 0 || throw(ArgumentError("the dimension must be positive"))
    family.dimension === nothing || family.dimension == n || throw(DimensionMismatch())
    return _with_dimension(family, Int(n), variables)
end
function _with_dimension(family::SetProg.Ellipsoid, n, vars)
    family.symmetric || throw(ArgumentError("a homogeneous ellipsoid must be symmetric"))
    family.point === nothing && family.superset === nothing ||
        throw(ArgumentError("point and superset are not supported for homogeneous gauges"))
    return SetProg.Ellipsoid(;
        symmetric = true,
        dimension = n,
        piecewise = family.piecewise,
    )
end
function _with_dimension(family::SetProg.Domain, n, vars)
    set = if _is_linear_copositive(family)
        SetProg.Polytope(; symmetric = family.set.symmetric, dimension = n)
    else
        _with_dimension(family.set, n, vars)
    end
    return SetProg.Domain(set, family.domain)
end
function _with_dimension(family::SetProg.Polytope, n, vars)
    family.piecewise !== nothing ||
        throw(ArgumentError("a polytope gauge requires a partition"))
    return SetProg.Polytope(;
        symmetric = family.symmetric,
        dimension = n,
        piecewise = family.piecewise,
    )
end
# Resolve the radial normalization once the system supplies its dimension.
function _with_dimension(family::_NormalizedFamily{<:SetProg.PolySet}, n, vars)
    set = _with_dimension(family.set, n, vars)
    return _with_superset(set, _unit_set(set; scale = family.reference))
end
function _with_dimension(family::_NormalizedFamily, n, vars)
    return _NormalizedFamily(
        _with_dimension(family.set, n, vars),
        family.reference;
        contains_reference = family.contains_reference,
        symmetric = family.symmetric,
    )
end
function _with_dimension(family::SetProg.PolySet, n, vars)
    family.symmetric ||
        throw(ArgumentError("a homogeneous polynomial set must be symmetric"))
    family.point === nothing ||
        throw(ArgumentError("point is not supported for homogeneous gauges"))
    x =
        family.variables === nothing ? (vars === nothing ? SetProg.new_polyvars(n) : vars) :
        family.variables
    length(x) == n || throw(DimensionMismatch())
    return SetProg.PolySet(;
        symmetric = true,
        degree = family.degree,
        dimension = n,
        convex = family.convex,
        variables = x,
        basis = family.basis,
        superset = family.superset,
    )
end

# The unit gauge used to normalize a set variable in a homogeneous certificate.
function _unit_set(f::SetProg.Ellipsoid)
    ball = SetProg.Sets.Ellipsoid(
        LinearAlgebra.Symmetric(Matrix{Float64}(LinearAlgebra.I, f.dimension, f.dimension)),
    )
    f.piecewise === nothing && return ball
    return SetProg.Sets.Piecewise(
        [ball for _ in SetProg.halfspaces(f.piecewise)],
        f.piecewise,
    )
end
_unit_set(f::SetProg.Domain{<:SetProg.Polytope}) =
    LinearCopositiveFunction(ones(f.dimension))
function _unit_set(f::SetProg.Polytope)
    return SetProg.Sets.Piecewise(
        [SetProg.Sets.PolarPoint(h.a / h.β) for h in SetProg.halfspaces(f.piecewise)],
        f.piecewise,
    )
end

function _unit_set(f::SetProg.PolySet; scale = 1)
    return SetProg.Sets.PolySet(f.degree, scale * sum(f.variables .^ 2)^div(f.degree, 2))
end

function _unit_set(f::_NormalizedFamily)
    if f.reference isa Real
        unit = LinearCopositiveFunction(fill(f.reference, f.dimension))
        return f.contains_reference ? SetProg.polar(unit) : unit
    end
    return f.reference
end

# Use SetProg's PSD/SOS remainder to enforce normalization at construction.
_with_superset(::SetProg.AbstractVariable, unit) = nothing
function _with_superset(f::SetProg.Ellipsoid, unit)
    # A bound on a cone need not hold globally for its quadratic piece.
    (f.piecewise !== nothing || f.superset !== nothing) && return nothing
    return SetProg.Ellipsoid(;
        symmetric = f.symmetric,
        dimension = f.dimension,
        superset = unit,
    )
end
function _with_superset(f::SetProg.PolySet, unit)
    # SetProg does not support a superset for convex polynomial families.
    f.superset !== nothing && return f
    f.convex && return nothing
    return SetProg.PolySet(;
        symmetric = f.symmetric,
        degree = f.degree,
        dimension = f.dimension,
        variables = f.variables,
        basis = f.basis,
        superset = unit,
    )
end

# A homogeneous set variable, named after `node`.
function add_function_variables!(
    model::JuMP.Model,
    family::SetProg.AbstractVariable,
    n::Integer,
    node::Integer,
)
    variable = _with_dimension(family, n)
    return JuMP.@variable(model, variable_type = variable, base_name = "S_$node")
end

# Ellipsoid and polynomial families use SetProg's `superset` construction when
# supported; other families use an inclusion constraint.
function add_normalization!(
    model::JuMP.Model,
    family::SetProg.AbstractVariable,
    S::SetProg.SetVariableRef;
    conditioning_bound::Real = Inf,
)
    conditioning_bound >= 1 || throw(ArgumentError("conditioning_bound must be at least 1"))
    unit = _unit_set(S.set)
    normalized = _with_superset(S.set, unit)
    if normalized !== nothing
        S.set = normalized
    elseif family isa _NormalizedFamily && family.contains_reference
        JuMP.@constraint(model, unit ⊆ S)
    else
        JuMP.@constraint(model, S ⊆ unit)
    end
    if family isa _NormalizedFamily && family.symmetric
        n = family.dimension
        JuMP.@constraint(model, (-Matrix{Float64}(LinearAlgebra.I, n, n)) * S ⊆ S)
    end
    if isfinite(conditioning_bound)
        S.set isa SetProg.Ellipsoid && S.set.piecewise === nothing ||
            throw(ArgumentError("conditioning bounds require an ellipsoid"))
        bound = SetProg.Sets.Ellipsoid(
            LinearAlgebra.Symmetric(
                conditioning_bound *
                Matrix{Float64}(LinearAlgebra.I, S.set.dimension, S.set.dimension),
            ),
        )
        JuMP.@constraint(model, bound ⊆ S)
    end
    return nothing
end

# The decrease as a set inclusion: `(A / γ) * source ⊆ destination`.
function add_decrease!(
    model::JuMP.Model,
    family::SetProg.AbstractVariable,
    source::SetProg.SetVariableRef,
    destination::SetProg.SetVariableRef,
    A::AbstractMatrix;
    scale::Real = 1,
)
    scale >= 0 || throw(ArgumentError("the scale must be nonnegative"))
    if iszero(scale)
        iszero(A) || JuMP.@constraint(model, zero(JuMP.AffExpr) >= 1)
        return nothing
    end
    γ = scale^(1 / homogeneity_degree(family))
    JuMP.@constraint(model, (A / γ) * source ⊆ destination)
    return nothing
end

solution_value(::SetProg.AbstractVariable, variable::SetProg.SetVariableRef) =
    JuMP.value(variable)

# Polynomial and piecewise-quadratic slacks would need an optimization of their
# own, and are not implemented.
function decrease_slack(
    ::SetProg.Ellipsoid,
    source::SetProg.Sets.Ellipsoid,
    destination::SetProg.Sets.Ellipsoid,
    A;
    scale = 1,
)
    return minimum(
        LinearAlgebra.eigvals(
            LinearAlgebra.Symmetric(Matrix(scale * source.Q - A' * destination.Q * A)),
        ),
    )
end
function decrease_slack(family::SetProg.AbstractVariable, source, destination, A; scale = 1)
    return throw(ArgumentError("decrease slacks are not implemented for $(typeof(family))"))
end

# Whether the homogeneous gauge family has an implemented dual family.
function _supports_dual(::SetProg.AbstractVariable)
    return false
end
_supports_dual(f::SetProg.Ellipsoid) = f.symmetric && f.piecewise === nothing
_supports_dual(f::SetProg.Domain) = _is_linear_copositive(f)
_supports_dual(f::_NormalizedFamily) = _supports_dual(f.set)

# The family of dual homogeneous gauges. On the positive orthant this uses
# blocking duality between positive simplices and boxes.
_dual_family(f::SetProg.Ellipsoid) =
    _supports_dual(f) ? f :
    throw(ArgumentError("piecewise ellipsoid duals are not implemented"))
_dual_family(f::SetProg.Domain) = _NormalizedFamily(f, 1)
function _dual_family(f::_NormalizedFamily)
    if f.contains_reference && f.reference == 1
        return f.set
    end
    return _NormalizedFamily(
        f.set,
        f.reference;
        contains_reference = !f.contains_reference,
        symmetric = f.symmetric,
    )
end

# The fitted dual gauge, represented as a set in the primal space.
_dual_value(set::SetProg.Sets.Ellipsoid) =
    SetProg.Sets.Ellipsoid(LinearAlgebra.Symmetric(inv(set.Q)))

_dual_value(
    set::Union{
        _LinearCopositiveSet,
        SetProg.Sets.PolarOf{<:_LinearCopositiveSet},
        _LinearPolytope,
        SetProg.Sets.PolarOf{<:_LinearPolytope},
    },
) = SetProg.Polyhedra.polar(set)

# A convex piecewise-linear gauge is the maximum of its linear pieces.
_polytope_value(set::_LinearPolytope, x) =
    maximum(piece -> LinearAlgebra.dot(piece.a, x), set.sets)

_gauge(V::_LinearPolytope, x) = _polytope_value(V, x)

function _polytope_slack(source::_LinearPolytope, destination::_LinearPolytope, A, scale)
    return minimum(
        scale * LinearAlgebra.dot(s.a, SetProg.Polyhedra.coord(r)) -
        _polytope_value(destination, A * SetProg.Polyhedra.coord(r)) for
        (s, cone) in zip(source.sets, source.pieces) for r in SetProg.rays(cone)
    )
end
function decrease_slack(
    ::SetProg.Polytope,
    source::_LinearPolytope,
    destination::_LinearPolytope,
    A;
    scale = 1,
)
    return _polytope_slack(source, destination, A, scale)
end
function decrease_slack(
    ::SetProg.Polytope,
    source::SetProg.Sets.PolarOf{<:_LinearPolytope},
    destination::SetProg.Sets.PolarOf{<:_LinearPolytope},
    A;
    scale = 1,
)
    return _polytope_slack(
        SetProg.Polyhedra.polar(destination),
        SetProg.Polyhedra.polar(source),
        A',
        scale,
    )
end
function decrease_slack(
    ::SetProg.Domain{<:SetProg.Polytope},
    source::_LinearCopositiveSet,
    destination::_LinearCopositiveSet,
    A;
    scale = 1,
)
    # A negative matrix entry sends an orthant direction outside the domain.
    all(>=(0), A) || return -Inf
    return minimum(scale * source.set.a - A' * destination.set.a)
end

function decrease_slack(f::_NormalizedFamily, source, destination, A; scale = 1)
    return decrease_slack(f.set, source, destination, A; scale)
end
function decrease_slack(
    ::SetProg.Domain{<:SetProg.Polytope},
    source::SetProg.Sets.PolarOf{<:_LinearCopositiveSet},
    destination::SetProg.Sets.PolarOf{<:_LinearCopositiveSet},
    A;
    scale = 1,
)
    all(>=(0), A) || return -Inf
    return minimum(
        scale * SetProg.polar(destination).set.a - A * SetProg.polar(source).set.a,
    )
end

_gauge(V::SetProg.Sets.Ellipsoid, x) = LinearAlgebra.dot(x, V.Q * x)
_gauge(V::SetProg.Sets.PolarPoint, x) = LinearAlgebra.dot(V.a, x)
function _gauge(V::SetProg.Sets.Intersection, x)
    return x in V.domain ? _gauge(V.set, x) : Inf
end
function _gauge(V::SetProg.Sets.Piecewise, x)
    i = findfirst(cone -> x in cone, V.pieces)
    return _gauge(V.sets[i], x)
end
function _gauge(V::SetProg.Sets.PolarOf{<:_LinearCopositiveSet}, x)
    inner = SetProg.polar(V)
    return x in inner.domain ? maximum(x ./ inner.set.a) : Inf
end
function _gauge(V::SetProg.Sets.PolarOf{<:_LinearPolytope}, x)
    inner = SetProg.polar(V)
    return maximum(
        LinearAlgebra.dot(x, SetProg.Polyhedra.coord(r)) /
        LinearAlgebra.dot(s.a, SetProg.Polyhedra.coord(r)) for
        (s, cone) in zip(inner.sets, inner.pieces) for r in SetProg.rays(cone)
    )
end

_gauge(V::Union{SetProg.Sets.PolySet, SetProg.Sets.ConvexPolySet}, x) =
    SetProg.sublevel_eval(V, x)
