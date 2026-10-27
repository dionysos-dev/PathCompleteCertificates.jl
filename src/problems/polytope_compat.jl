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
    ParallelFacesPolyhedralTemplate(n_nodes, dimension; min_weight = 1)
    ParallelFacesPolyhedralTemplate(matrices; min_weight = 1)

The polyhedral functions ``V(x) = \\max_k |(G x)_k| / w_k``, whose faces come
in parallel pairs, normal to the rows of ``G``, as one SetProg polytope per
node: ``G`` is the identity, of size `dimension`, at each of `n_nodes` nodes,
or one of the invertible `matrices` per node. The weights ``w`` are the variables. It
applies to every system, for stability, and gives linear programs.
`min_weight` normalizes the node functions: every weight is at least
`min_weight`.
"""
function ParallelFacesPolyhedralTemplate(
    n_nodes::Integer,
    dimension::Integer;
    min_weight = 1,
)
    n_nodes > 0 || throw(ArgumentError("at least one node is required"))
    dimension > 0 || throw(ArgumentError("the dimension must be positive"))
    identity = Matrix{Float64}(LinearAlgebra.I, dimension, dimension)
    return ParallelFacesPolyhedralTemplate(fill(identity, n_nodes); min_weight)
end
function ParallelFacesPolyhedralTemplate(
    matrices::AbstractVector{<:AbstractMatrix};
    min_weight = 1,
)
    isempty(matrices) && throw(ArgumentError("at least one matrix is required"))
    isfinite(min_weight) && min_weight > 0 ||
        throw(ArgumentError("min_weight must be finite and positive"))
    n = LinearAlgebra.checksquare(first(matrices))
    n > 0 || throw(ArgumentError("the dimension must be positive"))
    all(G -> size(G) == (n, n), matrices) || throw(DimensionMismatch())
    return map(matrices) do G
        LinearAlgebra.rank(G) == n ||
            throw(ArgumentError("node matrices must be invertible"))
        partition = _parallel_faces_partition(G)
        family = SetProg.Polytope(; symmetric = true, piecewise = partition)
        reference = ParallelFacesPolyhedralFunction(G, fill(min_weight, n); partition)
        return _NormalizedFamily(family, reference; symmetric = true)
    end
end
function _parallel_faces_partition(G)
    vertices = [collect(v) for v in eachcol(Matrix(G'))]
    return SetProg.polyhedron(SetProg.vrep(vcat(vertices, [-v for v in vertices])))
end

"""
    ConicPolyhedralTemplate(node_partitions; min_scale = 1)

The polyhedral functions linear on each cone over the facets of a polytope, as
one SetProg polytope per node, with the polytope of each node in
`node_partitions`; each polytope must contain the origin in its interior, and
[`planar_conic_partition`](@ref) builds one in the plane. It applies to every
system, for stability, and gives linear programs. `min_scale` normalizes the
node functions: each is at least `min_scale` times the function equal to one
on the boundary of its polytope.
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

A partition of the plane for [`ConicPolyhedralTemplate`](@ref): a centrally
symmetric polygon with `8 * 2^(order - 1)` facets. The cones over its facets
lie between the rays of ``(1, 0)``, ``(1, 1)``, ``(0, 1)``, ``(-1, 1)`` and
their opposites, each split in two at every further order by the sum of its
two rays. `library` gives a Polyhedra library, with a linear programming
solver.
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
"""
    ParallelFacesPolyhedralFunction(G, w)

The function ``V(x) = \\max_k |(G x)_k| / w_k``, a node function of
[`ParallelFacesPolyhedralTemplate`](@ref), as a SetProg set; evaluate it with
[`node_value`](@ref).
"""
function ParallelFacesPolyhedralFunction(
    G::AbstractMatrix,
    w::AbstractVector;
    partition = _parallel_faces_partition(G),
)
    n = LinearAlgebra.checksquare(G)
    length(w) == n || throw(DimensionMismatch())
    all(>(0), w) || throw(ArgumentError("weights must be positive"))
    pieces = [
        SetProg.Sets.PolarPoint(G \ (w .* (G * (h.a / h.β)))) for
        h in SetProg.halfspaces(partition)
    ]
    return SetProg.polar(SetProg.Sets.Piecewise(pieces, partition))
end
