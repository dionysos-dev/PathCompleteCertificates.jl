"""
    PiecewiseLinearTemplate(node_partitions; min_scale = 1)

The polyhedral functions linear on each cone over the facets of a polytope, as
one SetProg polytope per node, with the polytope of each node in
`node_partitions`; each polytope must contain the origin in its interior, and
[`planar_conic_partition`](@ref) builds one in the plane. It applies to every
system. Stability gives linear programs; safety with an ellipsoidal initial
region and an exterior-ellipsoid unsafe region gives second-order cone
programs. `min_scale` normalizes the stability node functions: each is at
least `min_scale` times the function equal to one on the boundary of its
polytope.
"""
function PiecewiseLinearTemplate(node_partitions; min_scale = 1)
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

A partition of the plane for [`PiecewiseLinearTemplate`](@ref): a centrally
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
