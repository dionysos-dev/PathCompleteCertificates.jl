# The three lifts whose nodes are subsets or multisets of the original nodes
# (Debauche, Della Rossa & Jungers, Defs. 8-9). They never move the bound -- the
# original graph is a path-complete component of each -- so they are exhibits
# of the ordering questions that `simulation_relation` and `conic_witness`
# decide without building them. Exponential in the number of nodes, and
# guarded accordingly.

const _SUBSET_LIFT_NODE_LIMIT = 12

function _check_subset_size(g::CertificateGraph, what::AbstractString)
    is_letter_graph(g) || throw(ArgumentError("the $what is defined on letter graphs"))

    n_nodes(g) <= _SUBSET_LIFT_NODE_LIMIT || throw(
        ArgumentError(
            "the $what of a graph with $(n_nodes(g)) nodes has too many nodes to " *
            "build; the ordering questions it answers are decided without it by " *
            "`simulation_relation` and `conic_witness`",
        ),
    )

    return nothing
end

# The nonempty subsets of 1:n as bitmasks, and the members of a mask.
_masks(n::Integer) = 1:(2 ^ n - 1)
_members(mask::Integer, n::Integer) =
    [node for node in 1:n if (mask >> (node - 1)) & 1 == 1]

"""
    MinLift()

Nodes are the nonempty subsets of the original nodes; `(A, B, i)` is an edge
when every node of `A` has an `i`-edge into `B` (Debauche, Della Rossa &
Jungers, Def. 9). The node function is the minimum over the subset.

Requires a template closed under [`Minimum`](@ref). It never improves the
bound — the singletons are a copy of the original graph — and is the exhibit of
the question [`simulation_relation`](@ref) decides in polynomial time: whether
this lift simulates another graph. Built explicitly only for small graphs.
"""
struct MinLift <: AbstractLift end

scope(::MinLift) = Global()

requirements(::MinLift) = (Minimum(),)

function (::MinLift)(g::CertificateGraph)
    _check_subset_size(g, "min lift")

    n = n_nodes(g)
    letters = sort(alphabet(g))
    index = successors(letter_graph(g))
    masks = collect(_masks(n))

    # The nodes of B that a node reaches under i, as a mask, for every node.
    reach = Dict{Tuple{Int, Int}, Int}()
    for ((node, letter), targets) in index
        reach[(node, letter)] = sum(1 << (target - 1) for target in unique(targets))
    end

    lifted = empty_graph(length(masks))

    for (a, A) in enumerate(masks), letter in letters
        members = _members(A, n)
        all(node -> haskey(reach, (node, letter)), members) || continue

        for (b, B) in enumerate(masks)
            all(node -> (reach[(node, letter)] & B) != 0, members) &&
                add_edge!(lifted, a, b, letter)
        end
    end

    return Lifted(lifted, [_members(mask, n) for mask in masks])
end

"""
    MaxLift()

Nodes are the nonempty subsets; `(A, B, i)` is an edge when every node of `B`
is reached by an `i`-edge from `A` (Debauche, Della Rossa & Jungers, Def. 9).
The dual of [`MinLift`](@ref) (Debauche, Lemma 7.45); requires a template closed
under [`Maximum`](@ref).
"""
const MaxLift = DualLift{MinLift}

MaxLift() = DualLift(MinLift())

"""
    SumLift(T)

Nodes are the multisets of `T` original nodes; `(P, Q, i)` is an edge when the
`i`-edges from `P` to `Q` admit a perfect matching (Debauche, Della Rossa &
Jungers, Def. 8; Debauche, Prop. 7.16). The node function is the sum over the
multiset.

Requires a template closed under [`Addition`](@ref). Self-dual. Never improves
the bound; the exhibit of the question [`conic_witness`](@ref) decides by a
linear program. Built explicitly only for small graphs. `origins` are the
multisets as sorted vectors.
"""
struct SumLift <: AbstractLift
    terms::Int

    function SumLift(terms::Integer)
        terms >= 1 || throw(ArgumentError("the number of terms must be positive"))
        return new(terms)
    end
end

scope(::SumLift) = Global()

requirements(::SumLift) = (Addition(),)

function (lift::SumLift)(g::CertificateGraph)
    _check_subset_size(g, "sum lift")

    n = n_nodes(g)
    letters = sort(alphabet(g))
    index = successors(letter_graph(g))
    multisets = _multisets(n, lift.terms)

    lifted = empty_graph(length(multisets))

    for (p, P) in enumerate(multisets), (q, Q) in enumerate(multisets), letter in letters
        _has_perfect_matching(P, Q, letter, index) && add_edge!(lifted, p, q, letter)
    end

    return Lifted(lifted, multisets)
end

# The multisets of size k over 1:n, each as a sorted vector.
function _multisets(n::Integer, k::Integer)
    result = Vector{Int}[]

    function extend(prefix, smallest)
        if length(prefix) == k
            push!(result, copy(prefix))
            return nothing
        end
        for node in smallest:n
            push!(prefix, node)
            extend(prefix, node)
            pop!(prefix)
        end
        return nothing
    end

    extend(Int[], 1)
    return result
end

# Whether the slots of P can be matched one-to-one onto the slots of Q along
# edges reading `letter`: augmenting paths, which is all a bipartite graph of a
# few slots a side needs.
function _has_perfect_matching(P, Q, letter, index)
    adjacent(i, j) = Q[j] in get(index, (P[i], letter), Int[])
    matched = zeros(Int, length(Q))

    function augment(i, visited)
        for j in eachindex(Q)
            (adjacent(i, j) && !visited[j]) || continue
            visited[j] = true
            if matched[j] == 0 || augment(matched[j], visited)
                matched[j] = i
                return true
            end
        end
        return false
    end

    return all(i -> augment(i, falses(length(Q))), eachindex(P))
end
