"""
    DualPiecewiseLinearTemplate(node_partitions; min_weight = 1)
    DualPiecewiseLinearTemplate(matrices; min_weight = 1)
    DualPiecewiseLinearTemplate(n_nodes, dimension; min_weight = 1)

The duals of the functions of [`PiecewiseLinearTemplate`](@ref): at each node,
the gauge of the polar of a set linear on each cone over the facets of the
polytope in `node_partitions`. It is
[`dual`](@ref)`(PiecewiseLinearTemplate(node_partitions; min_scale = min_weight))`,
and `min_weight` normalizes the node functions through that polar.

With one invertible matrix ``G`` per node in `matrices`, the polytope has the
rows of ``G`` and their opposites as vertices, and the node functions are
``V(x) = \\max_k |(G x)_k| / w_k``, whose faces come in parallel pairs, normal
to the rows of ``G``, with every weight ``w_k`` at least `min_weight`.
`(n_nodes, dimension)` takes the identity at each of `n_nodes` nodes, which
gives boxes.

It applies to every system. Stability gives linear programs, and safety, with
an ellipsoidal ``X_0`` and an ``X_u`` outside an ellipsoid, second-order cone
programs.
"""
function DualPiecewiseLinearTemplate(
    node_partitions::AbstractVector{<:SetProg.Polyhedra.Polyhedron};
    min_weight = 1,
)
    isfinite(min_weight) && min_weight > 0 ||
        throw(ArgumentError("min_weight must be finite and positive"))
    return dual(PiecewiseLinearTemplate(node_partitions; min_scale = min_weight))
end
function DualPiecewiseLinearTemplate(
    matrices::AbstractVector{<:AbstractMatrix};
    min_weight = 1,
)
    isempty(matrices) && throw(ArgumentError("at least one matrix is required"))
    n = LinearAlgebra.checksquare(first(matrices))
    n > 0 || throw(ArgumentError("the dimension must be positive"))
    all(G -> size(G) == (n, n), matrices) || throw(DimensionMismatch())
    partitions = map(matrices) do G
        LinearAlgebra.rank(G) == n ||
            throw(ArgumentError("node matrices must be invertible"))
        return _parallel_faces_partition(G)
    end
    return DualPiecewiseLinearTemplate(partitions; min_weight)
end
function DualPiecewiseLinearTemplate(n_nodes::Integer, dimension::Integer; min_weight = 1)
    n_nodes > 0 || throw(ArgumentError("at least one node is required"))
    dimension > 0 || throw(ArgumentError("the dimension must be positive"))
    identity = Matrix{Float64}(LinearAlgebra.I, dimension, dimension)
    return DualPiecewiseLinearTemplate(fill(identity, n_nodes); min_weight)
end

# The cross-polytope with the rows of `G` and their opposites as vertices: its
# polar has faces in parallel pairs, normal to the rows of `G`.
function _parallel_faces_partition(G)
    vertices = [collect(v) for v in eachcol(Matrix(G'))]
    return SetProg.polyhedron(SetProg.vrep(vcat(vertices, [-v for v in vertices])))
end
