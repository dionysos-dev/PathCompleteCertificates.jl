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
    DualCopositiveFunction(v)

The function ``V(x) = \\max_i x_i / v_i`` on the nonnegative orthant, a node
function of [`DualCopositiveTemplate`](@ref), as a SetProg set. Evaluate it
with [`node_value`](@ref).
"""
DualCopositiveFunction(v::AbstractVector) = _dual_value(LinearCopositiveFunction(v))
