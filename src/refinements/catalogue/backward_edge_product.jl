"""
    BackwardEdgeProduct()

Replace each given edge `(s, d, w)` by the edges `(s′, d, u·w)` for every
edge `(s′, s, u)`. The dual of [`ForwardEdgeProduct`](@ref).
"""
const BackwardEdgeProduct = DualRefinement{ForwardEdgeProduct}

BackwardEdgeProduct() = DualRefinement(ForwardEdgeProduct())
