"""
    Comparison

What [`compare`](@ref) returns: the [`lifts`](@ref) tried, the
[`simulations`](@ref) found and the [`templates`](@ref) proved.
"""
struct Comparison
    lifts::Vector{AbstractLift}
    simulations::Vector{Pair{AbstractLift, Any}}
    templates::Vector{_SetFamily}
end

"""
    lifts(comparison)

The lifts [`compare`](@ref) tried, in order.
"""
lifts(comparison::Comparison) = comparison.lifts

"""
    simulations(comparison)

The pairs `lift => simulation`, one per lift whose lifted first graph
simulates the second.
"""
simulations(comparison::Comparison) = comparison.simulations

"""
    templates(comparison)

The given templates for which the second graph is proved no worse than the
first.
"""
templates(comparison::Comparison) = comparison.templates

const _LIFTS = (
    IdentityLift(),
    MinLift(),
    MaxLift(),
    SumLift(),
    CompositionLift(1),
    BackwardCompositionLift(1),
)

"""
    compare(G, H; templates = (), system = nothing, optimizer = nothing,
            lifts = (IdentityLift(), MinLift(), MaxLift(), SumLift(),
                     CompositionLift(1), BackwardCompositionLift(1)))

Whether ``G ≤_V H``, and for which of `templates`, as a [`Comparison`](@ref).
The lifts are tried in order, and the identity lift's simulation ends the
search. The sum lift is tried only with an `optimizer`, and `system` is
required when `templates` is nonempty. Both graphs need one mode per edge.
"""
function compare(
    G::CertificateGraph,
    H::CertificateGraph;
    templates = (),
    system = nothing,
    optimizer = nothing,
    lifts = _LIFTS,
)
    G = _letter_graph(G, "compare")
    H = _letter_graph(H, "compare")
    isempty(templates) ||
        system !== nothing ||
        throw(ArgumentError("reading the templates' closures needs the system"))

    tried = AbstractLift[]
    found = Pair{AbstractLift, Any}[]

    for L in lifts
        L isa SumLift{Nothing} && optimizer === nothing && continue
        push!(tried, L)

        R = simulation(L, G, H; optimizer)
        R === nothing && continue
        push!(found, L => R)

        L isa IdentityLift && break
    end

    proven = _SetFamily[
        template for
        template in templates if any(is_valid(L, template, system) for (L, _) in found)
    ]

    return Comparison(tried, found, proven)
end
