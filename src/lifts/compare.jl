"""
    Comparison

What [`compare`](@ref) returns for two graphs `G` and `H`: the [`lifts`](@ref)
tried, in order; the [`simulations`](@ref) found, one per lift whose lifted `G`
simulates `H`; and the [`templates`](@ref) proved no worse on `H` than on
`G`, among those given.

Read without templates, it is the literature's sentence: `H` is no worse than
`G` for every template closed under the [`requirements`](@ref) of each lift
that found a simulation, and for every template at all when the identity lift
did.
"""
struct Comparison{G <: CertificateGraph, H <: CertificateGraph}
    G::G
    H::H
    lifts::Vector{AbstractLift}
    simulations::Vector{Pair{AbstractLift, Any}}
    templates::Vector{AbstractTemplate}
end

"""
    lifts(comparison)

The lifts [`compare`](@ref) tried, in the order it tried them. The sum lift
over every size is tried only with an optimizer, and nothing after the
identity lift once it has found a map.
"""
lifts(comparison::Comparison) = comparison.lifts

"""
    simulations(comparison)

The pairs `lift => simulation` of a [`Comparison`](@ref), one per lift whose
lifted graph simulates the second: a map, a relation, a map into multisets or
words, or the integer matrix of the sum lift — what [`simulation`](@ref)
returned, and the recipe for a certificate on the second graph from one on the
first.
"""
simulations(comparison::Comparison) = comparison.simulations

"""
    templates(comparison)

The templates given to [`compare`](@ref) for which the second graph is proved
no worse than the first: those for which some lift with a simulation
[`is_valid`](@ref) on the system.
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
    compare(G, H; templates = (), system = nothing, optimizer = nothing, lifts = …)

Decide whether `H` is no worse a graph than `G` — ``G ≤_V H`` in Debauche,
Della Rossa & Jungers, Def. 4: every system certified on `G` in a template `V`
is certified on `H` in the same template — and for which templates.

Each lift in `lifts` is asked for its [`simulation`](@ref) of `H` by the
lifted `G`, cheapest and strongest first: the identity lift, whose map settles
the question for every template and stops the search; the min and max lifts,
by a relation; the sum lift, by a linear program, tried only when an
`optimizer` is given; the two composition lifts of length one. A template of
`templates` is proved when some lift with a simulation [`is_valid`](@ref) for it on
`system`, which is required with them. Returns a [`Comparison`](@ref). Letter
graphs only.
"""
function compare(
    G::CertificateGraph,
    H::CertificateGraph;
    templates = (),
    system = nothing,
    optimizer = nothing,
    lifts = _LIFTS,
)
    _require_letters(G, "compare")
    _require_letters(H, "compare")
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

    proven = AbstractTemplate[
        template for
        template in templates if any(is_valid(L, template, system) for (L, _) in found)
    ]

    return Comparison(G, H, tried, found, proven)
end
