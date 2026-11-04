"""
    DualPiecewiseLinearTemplate(n_nodes, dimension; min_weight = 1)
    DualPiecewiseLinearTemplate(matrices; min_weight = 1)

The polyhedral functions ``V(x) = \\max_k |(G x)_k| / w_k``, whose faces come
in parallel pairs, normal to the rows of ``G``, as one SetProg polytope per
node: ``G`` is the identity, of size `dimension`, at each of `n_nodes` nodes,
or one of the invertible `matrices` per node. The weights ``w`` are the variables. It
applies to every system. Stability gives linear programs; safety with an
ellipsoidal initial region and an exterior-ellipsoid unsafe region gives
second-order cone programs. `min_weight` normalizes the node functions: every
weight is at least `min_weight`. The underlying family is
[`PiecewiseLinearTemplate`](@ref) with partition `conv(±rows(G))`, using the
polar reference-set inclusion and central symmetry. SetProg selects the dual
representation.
"""
function DualPiecewiseLinearTemplate(n_nodes::Integer, dimension::Integer; min_weight = 1)
    n_nodes > 0 || throw(ArgumentError("at least one node is required"))
    dimension > 0 || throw(ArgumentError("the dimension must be positive"))
    identity = Matrix{Float64}(LinearAlgebra.I, dimension, dimension)
    return DualPiecewiseLinearTemplate(fill(identity, n_nodes); min_weight)
end
function DualPiecewiseLinearTemplate(
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
        family = only(
            PiecewiseLinearTemplate([_parallel_faces_partition(G)]; min_scale = min_weight),
        )
        # Polarity reverses the conic normalization S ⊆ reference. SetProg
        # selects dual modeling for polar(reference) ⊆ S.
        reference = SetProg.polar(_unit_set(family))
        return _NormalizedFamily(family, reference; symmetric = true)
    end
end

# The cross-polytope with the rows of `G` and their opposites as vertices: its
# polar has faces in parallel pairs, normal to the rows of `G`.
function _parallel_faces_partition(G)
    vertices = [collect(v) for v in eachcol(Matrix(G'))]
    return SetProg.polyhedron(SetProg.vrep(vcat(vertices, [-v for v in vertices])))
end
