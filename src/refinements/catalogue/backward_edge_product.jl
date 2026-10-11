"""
    BackwardEdgeProduct()

Replace each edge `(s, d, w)` of the locus by the edges `(s′, d, u·w)` for every
edge `(s′, s, u)` entering its source (Athanasopoulos & Jungers, Def. 5, the
partial T\\*-lift). The dual of [`ForwardEdgeProduct`](@ref).
"""
const BackwardEdgeProduct = DualRefinement{ForwardEdgeProduct}

BackwardEdgeProduct() = DualRefinement(ForwardEdgeProduct())
