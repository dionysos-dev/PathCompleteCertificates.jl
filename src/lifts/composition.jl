# The composition lift (Debauche, Della Rossa & Jungers, Def. 10; Debauche,
# Def. 7.58; Jongeneel & Jungers, Def. III.1): a node commits to the next T
# modes, and its function is the original one composed with them.

"""
    CompositionLift(T)

The `T`-forward composition lift: a node `(s, j₁, …, j_T)` for every node `s`
and every `T`-tuple of modes, and for every edge `(a, b, i)` and tuple the edge
`((a, j₁…j_T), (b, i, j₁…j_{T−1}), j_T)`. The node function is
``V_s ∘ A_{j_1} ∘ ⋯ ∘ A_{j_T}``.

Requires the template to be closed under [`Composition`](@ref) with the
dynamics, which for the templates here means invertible mode matrices. Unlike
the subset lifts it can strictly improve the bound (Jongeneel & Jungers,
Ex. IV.4). Its dual, `dual(CompositionLift(T))`, is the backward composition
lift, requiring [`InverseComposition`](@ref).

The tuples range over the modes the graph reads, which are the system's on any
path-complete graph. Letter graphs only. `origins` are the `(s, [j₁, …, j_T])`
pairs.
"""
struct CompositionLift <: AbstractLift
    length::Int

    function CompositionLift(length::Integer)
        length >= 1 || throw(ArgumentError("the length must be positive"))
        return new(length)
    end
end

scope(::CompositionLift) = Global()

requirements(::CompositionLift) = (Composition(),)

function (lift::CompositionLift)(g::CertificateGraph)
    is_letter_graph(g) ||
        throw(ArgumentError("the composition lift is defined on letter graphs"))

    modes = sort(alphabet(g))
    tuples = vec(collect(Iterators.product(ntuple(_ -> modes, lift.length)...)))

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
