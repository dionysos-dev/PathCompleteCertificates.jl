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
    LinearCopositiveFunction(c)

The function ``V(x) = c^\\top x`` on the nonnegative orthant, a node function
of [`LinearCopositiveTemplate`](@ref), as a SetProg set. Evaluate it with
[`node_value`](@ref).
"""
function LinearCopositiveFunction(c::AbstractVector)
    n = length(c)
    domain =
        SetProg.polyhedron(SetProg.hrep(-Matrix{Float64}(LinearAlgebra.I, n, n), zeros(n)))
    return SetProg.Sets.Intersection(SetProg.Sets.PolarPoint(collect(c)), domain)
end
