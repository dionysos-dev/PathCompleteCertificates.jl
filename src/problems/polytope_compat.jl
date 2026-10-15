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
    ConicPolyhedralTemplate(node_partitions; min_scale = 1)

One SetProg polytope per node. Each partition polytope describes the cones over
its facets and must contain the origin in its interior. `min_scale` scales the
partition's gauge used for normalization.
"""
function ConicPolyhedralTemplate(node_partitions; min_scale = 1)
    isempty(node_partitions) && throw(ArgumentError("at least one node is required"))
    isfinite(min_scale) && min_scale > 0 ||
        throw(ArgumentError("min_scale must be finite and positive"))
    all(p -> p isa SetProg.Polyhedra.Polyhedron, node_partitions) ||
        throw(ArgumentError("supply partition polytopes instead of separate cones"))
    return [
        SetProg.Polytope(;
            symmetric = true,
            piecewise = min_scale == 1 ? partition :
                        SetProg.polyhedron(
                inv(min_scale) * SetProg.vrep(partition),
                SetProg.Polyhedra.library(partition),
            ),
        ) for partition in node_partitions
    ]
end

"""
    planar_conic_partition(order; library = nothing)

Return a centrally symmetric partition polytope with `8 * 2^(order - 1)` facets.
The cones over its facets have the same boundary rays as the planar conic
partition. `library` can supply a Polyhedra library with an LP solver.
"""
function planar_conic_partition(order::Integer; library = nothing)
    order >= 1 || throw(ArgumentError("the order must be positive"))
    rays = [[1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [-1.0, 1.0], [-1.0, 0.0]]
    for _ in 2:order
        rays = vcat(
            [r for i in 1:(length(rays) - 1) for r in (rays[i], rays[i] + rays[i + 1])],
            [last(rays)],
        )
    end
    # Put every ray on a strictly convex curve so each becomes a vertex.
    vertices = [r / LinearAlgebra.norm(r) for r in rays[1:(end - 1)]]
    vertices = vcat(vertices, [-v for v in vertices])
    rep = SetProg.vrep(vertices)
    return library === nothing ? SetProg.polyhedron(rep) : SetProg.polyhedron(rep, library)
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
