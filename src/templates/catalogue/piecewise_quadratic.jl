"""
    PiecewiseQuadraticTemplate(node_partitions)

The functions quadratic on each cone over the facets of a polytope, as one
SetProg ellipsoid per node, piecewise on the polytope of that node in
`node_partitions`; each polytope must contain the origin in its interior, and
[`planar_conic_partition`](@ref) builds one in the plane. It applies to every
system, for stability and optimal control with fixed gains, gives semidefinite
programs, and needs `using SumOfSquares`, with which SetProg makes the pieces
agree on the boundaries of the cones. [`refine`](@ref) does not run on this
template: its edge slacks are not implemented. See [Choosing a template](@ref).
"""
function PiecewiseQuadraticTemplate(node_partitions)
    isempty(node_partitions) && throw(ArgumentError("at least one node is required"))
    all(p -> p isa SetProg.Polyhedra.Polyhedron, node_partitions) ||
        throw(ArgumentError("supply partition polytopes instead of separate cones"))
    return [
        SetProg.Ellipsoid(; symmetric = true, piecewise = partition) for
        partition in node_partitions
    ]
end
