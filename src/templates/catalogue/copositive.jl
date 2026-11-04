"""
    LinearCopositiveTemplate()

The linear functions ``V(x) = c^\\top x`` on the nonnegative orthant, as a
SetProg polytope on that orthant. It applies to positive systems, whose
matrices have nonnegative entries, for stability, and gives linear programs.
Its dual is [`DualCopositiveTemplate`](@ref). See [Choosing a template](@ref).
"""
LinearCopositiveTemplate() =
    SetProg.Domain(SetProg.Polytope(; symmetric = true), SetProg.MOI.Nonnegatives)

"""
    DualCopositiveTemplate(; min_weight = 1)

The functions ``V(x) = \\max_i x_i / v_i`` on the nonnegative orthant, the
duals of those of [`LinearCopositiveTemplate`](@ref), as a SetProg polytope on
that orthant. It applies to positive systems, for stability, and gives linear
programs. `min_weight` normalizes the node functions: every weight ``v_i`` is
at least `min_weight`.
"""
function DualCopositiveTemplate(; min_weight = 1)
    isfinite(min_weight) && min_weight > 0 ||
        throw(ArgumentError("min_weight must be finite and positive"))
    return _NormalizedFamily(LinearCopositiveTemplate(), min_weight)
end

"""
    LinearCopositiveFunction(c)

The function ``V(x) = c^\\top x`` on the nonnegative orthant, a node function
of [`LinearCopositiveTemplate`](@ref), as a SetProg set; evaluate it with
[`node_value`](@ref).
"""
function LinearCopositiveFunction(c::AbstractVector)
    n = length(c)
    domain =
        SetProg.polyhedron(SetProg.hrep(-Matrix{Float64}(LinearAlgebra.I, n, n), zeros(n)))
    return SetProg.Sets.Intersection(SetProg.Sets.PolarPoint(collect(c)), domain)
end

"""
    DualCopositiveFunction(v)

The function ``V(x) = \\max_i x_i / v_i`` on the nonnegative orthant, a node
function of [`DualCopositiveTemplate`](@ref), as a SetProg set; evaluate it
with [`node_value`](@ref).
"""
DualCopositiveFunction(v::AbstractVector) = _dual_value(LinearCopositiveFunction(v))
