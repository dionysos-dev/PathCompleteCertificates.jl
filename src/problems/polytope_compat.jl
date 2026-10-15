"""
    LinearCopositiveTemplate()

Linear gauges on the nonnegative orthant, represented by a SetProg polytope.
"""
LinearCopositiveTemplate() = SetProg.Polytope(; piecewise = :orthant, min_scale = 1)

"""
    DualCopositiveTemplate(; min_weight = 1)

Blocking polars of linear copositive gauges, represented by a SetProg polytope.
"""
DualCopositiveTemplate(; min_weight = 1) =
    SetProg.Polytope(; piecewise = :orthant, polar = true, min_scale = min_weight)

"""
    ParallelFacesPolyhedralTemplate(n_nodes, dimension; min_weight = 1)
    ParallelFacesPolyhedralTemplate(matrices; min_weight = 1)

One SetProg polytope per node, with prescribed pairs of parallel faces.
"""
function ParallelFacesPolyhedralTemplate(
    n_nodes::Integer,
    dimension::Integer;
    min_weight = 1,
)
    n_nodes > 0 || throw(ArgumentError("at least one node is required"))
    family = SetProg.Polytope(;
        symmetric = true,
        piecewise = :orthants,
        dimension = dimension,
        polar = true,
        min_scale = min_weight,
    )
    return fill(family, n_nodes)
end
function ParallelFacesPolyhedralTemplate(
    matrices::AbstractVector{<:AbstractMatrix};
    min_weight = 1,
)
    isempty(matrices) && throw(ArgumentError("at least one matrix is required"))
    n = size(first(matrices), 1)
    all(G -> size(G) == (n, n), matrices) || throw(DimensionMismatch())
    return [
        SetProg.Polytope(;
            symmetric = true,
            piecewise = :orthants,
            transform = Matrix(G'),
            polar = true,
            min_scale = min_weight,
        ) for G in matrices
    ]
end

"""
    ConicPolyhedralTemplate(node_cones; min_scale = 1)

One SetProg polytope per node, with linear pieces on the prescribed cones.
"""
function ConicPolyhedralTemplate(node_cones; min_scale = 1)
    isempty(node_cones) && throw(ArgumentError("at least one node is required"))
    return [
        SetProg.Polytope(; symmetric = true, piecewise = cones, min_scale = min_scale) for
        cones in node_cones
    ]
end

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

"""
    LinearCopositiveFunction(c)

A fitted linear copositive function represented by a SetProg set.
"""
function LinearCopositiveFunction(c::AbstractVector)
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
"""
    DualCopositiveFunction(v)

A fitted dual copositive function represented by a SetProg set.
"""
DualCopositiveFunction(v::AbstractVector) = _dual_value(LinearCopositiveFunction(v))
"""
    ParallelFacesPolyhedralFunction(G, w)

A fitted parallel-faces polyhedral function represented by a SetProg set.
"""
function ParallelFacesPolyhedralFunction(G::AbstractMatrix, w::AbstractVector)
    n = LinearAlgebra.checksquare(G)
    signs = vec([Float64[s...] for s in Iterators.product(ntuple(_ -> (-1, 1), n)...)])
    return SetProg.polar(
        SetProg.Sets.Piecewise(
            [inv(G) * (sign .* w) for sign in signs],
            [G' * LinearAlgebra.Diagonal(sign) for sign in signs],
        ),
    )
end
