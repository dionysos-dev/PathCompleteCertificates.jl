"""
    PositiveSimplex(; dimension = nothing, min_scale = 1)

Compatibility constructor for a linear gauge on the nonnegative orthant.
"""
PositiveSimplex(; dimension = nothing, min_scale = 1) =
    SetProg.Polytope(; piecewise = :orthant, dimension = dimension, min_scale = min_scale)

"""
    PositiveBox(; dimension = nothing, min_weight = 1)

Compatibility constructor for the blocking polar of a positive simplex.
"""
PositiveBox(; dimension = nothing, min_weight = 1) = SetProg.Polytope(;
    piecewise = :orthant,
    dimension = dimension,
    polar = true,
    min_scale = min_weight,
)

"""
    Parallelotope(G; min_weight = 1)
    Parallelotope(; dimension = nothing, min_weight = 1)

Compatibility constructor for the polar of a weighted absolute-value sum.
"""
Parallelotope(G::AbstractMatrix; min_weight = 1) = SetProg.Polytope(;
    symmetric = true,
    piecewise = :orthants,
    transform = Matrix(G'),
    polar = true,
    min_scale = min_weight,
)
Parallelotope(; dimension = nothing, min_weight = 1) = SetProg.Polytope(;
    symmetric = true,
    piecewise = :orthants,
    dimension = dimension,
    polar = true,
    min_scale = min_weight,
)

"""
    ConicPolytope(cones; min_scale = 1)

Compatibility constructor for a symmetric polytope with prescribed cones.
"""
ConicPolytope(cones::AbstractVector{<:AbstractMatrix}; min_scale = 1) =
    SetProg.Polytope(; symmetric = true, piecewise = cones, min_scale = min_scale)

"""
    planar_conic_partition(order)

Compatibility helper: subdivide the upper half-plane into partition cones.
"""
function planar_conic_partition(order::Integer)
    order >= 1 || throw(ArgumentError("the order must be positive"))
    rays = ([1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [-1.0, 1.0], [-1.0, 0.0])
    cones = [hcat(rays[i], rays[i + 1]) for i in 1:4]
    for _ in 2:order
        cones = [
            C for cone in cones for C in (
                hcat(cone[:, 1], sum(cone; dims = 2)),
                hcat(sum(cone; dims = 2), cone[:, 2]),
            )
        ]
    end
    return cones
end

function PositiveSimplex(c::AbstractVector)
    cone = Matrix{Float64}(LinearAlgebra.I, length(c), length(c))
    return SetProg.Sets.Intersection(
        SetProg.Sets.Piecewise([collect(c)], [cone]),
        SetProg.polyhedron(
            SetProg.vrep(
                [zeros(length(c))],
                SetProg.Line{Float64, Vector{Float64}}[],
                [SetProg.Ray(collect(ray)) for ray in eachcol(cone)],
            ),
        ),
    )
end
PositiveBox(v::AbstractVector) = SetProg.dual_value(PositiveSimplex(v))
function Parallelotope(G::AbstractMatrix, w::AbstractVector)
    n = LinearAlgebra.checksquare(G)
    signs = vec([Float64[s...] for s in Iterators.product(ntuple(_ -> (-1, 1), n)...)])
    return SetProg.polar(
        SetProg.Sets.Piecewise(
            [inv(G) * (sign .* w) for sign in signs],
            [G' * LinearAlgebra.Diagonal(sign) for sign in signs],
        ),
    )
end

"""
    LinearCopositiveTemplate()

Backward-compatible constructor for `Polytope(piecewise = :orthant)`.
"""
LinearCopositiveTemplate() = PositiveSimplex()

"""
    DualCopositiveTemplate(; min_weight = 1)

Backward-compatible constructor for a positive box polytope configuration.
"""
DualCopositiveTemplate(; min_weight = 1) = PositiveBox(; min_weight)

"""
    ParallelFacesPolyhedralTemplate(n_nodes, dimension; min_weight = 1)
    ParallelFacesPolyhedralTemplate(matrices; min_weight = 1)

Backward-compatible constructor for native polytopes, one per graph node.
"""
function ParallelFacesPolyhedralTemplate(
    n_nodes::Integer,
    dimension::Integer;
    min_weight = 1,
)
    n_nodes > 0 || throw(ArgumentError("at least one node is required"))
    return fill(Parallelotope(; dimension, min_weight), n_nodes)
end
function ParallelFacesPolyhedralTemplate(
    matrices::AbstractVector{<:AbstractMatrix};
    min_weight = 1,
)
    isempty(matrices) && throw(ArgumentError("at least one matrix is required"))
    return [Parallelotope(G; min_weight) for G in matrices]
end

"""
    ConicPolyhedralTemplate(node_cones; min_scale = 1)

Backward-compatible constructor for one native conic polytope per graph node.
"""
ConicPolyhedralTemplate(node_cones; min_scale = 1) =
    [ConicPolytope(cones; min_scale) for cones in node_cones]
