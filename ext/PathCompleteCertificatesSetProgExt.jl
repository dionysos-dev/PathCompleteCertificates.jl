# The methods of `SetProgTemplate`. Every primitive is a set inclusion, modeled
# in SetProg's primal space, the only one where the normalization `S ⊆ unit`
# can be written.
module PathCompleteCertificatesSetProgExt

import JuMP
import LinearAlgebra
import SetProg
import PathCompleteCertificates as PCC

const Sets = SetProg.Sets
const MP = SetProg.MP

function _variable(template::PCC.SetProgTemplate, node::Integer)
    template.shared && return only(template.variables)

    node <= length(template.variables) || throw(
        ArgumentError(
            "the template carries $(length(template.variables)) set variables " *
            "but the graph has at least $node nodes",
        ),
    )

    return template.variables[node]
end

_degree(::SetProg.Ellipsoid) = 2
_degree(variable::SetProg.PolySet) = variable.degree
_degree(::SetProg.Polytope) = 1

function PCC.homogeneity_degree(template::PCC.SetProgTemplate)
    degrees = unique(_degree.(template.variables))

    # One rate gamma^p for the whole graph needs one degree p.
    length(degrees) == 1 ||
        throw(ArgumentError("the set variables of every node must have the same degree"))

    return only(degrees)
end

# The variable with its dimension filled in, for `_unit` to read.
function _with_dimension(variable::SetProg.Ellipsoid, dimension)
    variable.point === nothing && variable.superset === nothing ||
        throw(ArgumentError("`point` and `superset` are not supported by SetProgTemplate"))
    variable.symmetric ||
        throw(ArgumentError("SetProgTemplate needs `Ellipsoid(symmetric = true)`"))
    _check_dimension(variable.piecewise, dimension)

    return SetProg.Ellipsoid(;
        symmetric = true,
        dimension = dimension,
        piecewise = variable.piecewise,
    )
end

function _with_dimension(variable::SetProg.Polytope, dimension)
    variable.symmetric && variable.piecewise !== nothing || throw(
        ArgumentError(
            "SetProgTemplate needs `Polytope(symmetric = true, piecewise = P)`: " *
            "without a partition the function is linear, not a gauge",
        ),
    )
    _check_dimension(variable.piecewise, dimension)

    return SetProg.Polytope(;
        symmetric = true,
        dimension = dimension,
        piecewise = variable.piecewise,
    )
end

function _with_dimension(variable::SetProg.PolySet, dimension)
    variable.point === nothing && variable.superset === nothing ||
        throw(ArgumentError("`point` and `superset` are not supported by SetProgTemplate"))
    variable.symmetric ||
        throw(ArgumentError("SetProgTemplate needs `PolySet(symmetric = true)`"))

    # The unit set must be written in the same polynomial variables.
    variable.variables === nothing && throw(
        ArgumentError(
            "SetProgTemplate needs the polynomial variables, " *
            "use `PolySet(variables = x, ...)`",
        ),
    )
    length(variable.variables) == dimension || throw(
        ArgumentError(
            "the set variable carries $(length(variable.variables)) polynomial " *
            "variables but the system has dimension $dimension",
        ),
    )

    return SetProg.PolySet(;
        symmetric = true,
        degree = variable.degree,
        dimension = dimension,
        convex = variable.convex,
        variables = variable.variables,
        basis = variable.basis,
    )
end

_check_dimension(::Nothing, _) = nothing

function _check_dimension(partition, dimension)
    SetProg.Polyhedra.fulldim(partition) == dimension || throw(
        ArgumentError(
            "the partition lives in R^$(SetProg.Polyhedra.fulldim(partition)) " *
            "but the system is $dimension-dimensional",
        ),
    )

    return nothing
end

function PCC.add_function_variables!(
    model::JuMP.Model,
    template::PCC.SetProgTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    variable = _with_dimension(_variable(template, node), dimension)

    return JuMP.@variable(model, variable_type = variable, base_name = "S_$(node)")
end

_identity(dimension) =
    LinearAlgebra.Symmetric(Matrix(1.0LinearAlgebra.I, dimension, dimension))

# The 1-sublevel set of `‖x‖₂^p`, or of the gauge of the partition for a
# polytope, in the representation of the set variable.
function _unit(variable::SetProg.Ellipsoid)
    ball = Sets.Ellipsoid(_identity(variable.dimension))
    variable.piecewise === nothing && return ball

    partition = variable.piecewise

    return Sets.Piecewise(
        [ball for _ in SetProg.Polyhedra.halfspaces(partition)],
        partition,
    )
end

function _unit(variable::SetProg.Polytope)
    partition = variable.piecewise
    facets = [Sets.PolarPoint(h.a / h.β) for h in SetProg.Polyhedra.halfspaces(partition)]

    return Sets.Piecewise(facets, partition)
end

function _unit(variable::SetProg.PolySet)
    half_degree = div(variable.degree, 2)
    monomials = MP.monomials(variable.variables, half_degree)

    # (x₁² + ⋯ + xₙ²)ᵈ = Σ_{|α| = d} d! / α! x^(2α), a diagonal Gram matrix.
    coefficients = [
        factorial(half_degree) / prod(factorial, MP.exponents(monomial)) for
        monomial in monomials
    ]
    gram = SetProg.GramMatrix(Matrix(LinearAlgebra.Diagonal(coefficients)), monomials)

    return Sets.PolySet(variable.degree, gram)
end

function PCC.add_normalization!(
    model::JuMP.Model,
    ::PCC.SetProgTemplate,
    S::SetProg.SetVariableRef,
)
    # `S ⊆ unit` is `V ≥ ‖x‖₂^p`, which only fixes the scale.
    JuMP.@constraint(model, S ⊆ _unit(S.set))

    return nothing
end

function PCC.add_decrease!(
    model::JuMP.Model,
    template::PCC.SetProgTemplate,
    S_src::SetProg.SetVariableRef,
    S_dst::SetProg.SetVariableRef,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    margin == 0 ||
        throw(ArgumentError("SetProgTemplate does not support a positive margin"))

    # `V_dst(A x) ≤ γᵖ V_src(x)` is `(A / γ) S_src ⊆ S_dst`, so γ must be a number.
    scale isa Real ||
        throw(ArgumentError("SetProgTemplate needs a constant scale, got $scale"))
    scale > 0 || throw(ArgumentError("the scale must be positive, got $scale"))

    gamma = scale^(1 / PCC.homogeneity_degree(template))

    JuMP.@constraint(model, (map ./ gamma) * S_src ⊆ S_dst)

    return nothing
end

PCC.solution_value(::PCC.SetProgTemplate, S::SetProg.SetVariableRef) =
    PCC.SetProgFunction(JuMP.value(S))

(V::PCC.SetProgFunction)(x::AbstractVector{<:Real}) = _evaluate(V.set, x)

_evaluate(set::Sets.Ellipsoid, x) = LinearAlgebra.dot(x, set.Q * x)

_evaluate(set::Union{Sets.PolySet, Sets.ConvexPolySet}, x) =
    MP.polynomial(set.p)(Sets.space_variables(set) => collect(x))

_evaluate(set::Sets.PolarPoint, x) = LinearAlgebra.dot(set.a, x)

function _evaluate(set::Sets.Piecewise, x)
    # Continuous, so a point on a boundary may use either piece.
    piece = findfirst(piece -> x in piece, set.pieces)
    piece === nothing && throw(ArgumentError("$x is in none of the pieces"))

    return _evaluate(set.sets[piece], x)
end

end
