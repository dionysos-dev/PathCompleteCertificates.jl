"""
    CompositionLift(T)

The `T`-forward composition lift: a node `(s, j₁, …, j_T)` per node `s` and
`T`-tuple of modes, and for each edge `(a, b, i)` an edge labelled `j_T` from
`(a, j₁…j_T)` to `(b, i, j₁…j_{T−1})`
[debauche2024thesis; Def. 7.58](@cite). Requires [`Composition`](@ref).
"""
struct CompositionLift <: AbstractLift
    length::Int

    function CompositionLift(length::Integer)
        length >= 1 || throw(ArgumentError("the length must be positive"))
        return new(length)
    end
end

requirements(::CompositionLift) = (Composition(),)

function lift(L::CompositionLift, g::CertificateGraph)
    _require_one_mode_per_edge(g, "the composition lift")

    modes = alphabet(g)
    tuples = vec(collect(Iterators.product(ntuple(_ -> modes, L.length)...)))

    origins = [(node, collect(Int, tuple)) for node in nodes(g) for tuple in tuples]
    index = Dict(origin => k for (k, origin) in enumerate(origins))

    lifted = empty_graph(length(origins))

    for edge in edges(g), tuple in tuples
        word = collect(Int, tuple)
        from = index[(source(edge), word)]
        to = index[(dest(edge), [only(letters(label(g, edge))); word[1:(end - 1)]])]
        add_edge!(lifted, from, to, last(word))
    end

    return Lifted(lifted, origins)
end
