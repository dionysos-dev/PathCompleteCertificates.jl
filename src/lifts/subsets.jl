_masks(n::Integer) = 1:(2 ^ n - 1)
_members(mask::Integer, n::Integer) =
    [node for node in 1:n if (mask >> (node - 1)) & 1 == 1]

"""
    MinLift()

Nodes are the nonempty subsets of the original nodes; `(A, B, i)` is an edge
when every node of `A` has an `i`-edge into `B` (Debauche, Della Rossa &
Jungers, Def. 9). The node function is the minimum over the subset.

Valid for templates closed under [`Minimum`](@ref), and for the linear
copositive norms on positive systems without closure (Debauche, Thm. 7.43).
Its simulation is the greatest [`simulation_relation`](@ref), a map into
subsets computed in polynomial time, and it is complete: `G ≤_V H` for every
`min`-closed template exactly when the relation exists (Debauche, Thm. 8.1).
Built explicitly only for small graphs; `origins` are the subsets.
"""
struct MinLift <: AbstractLift end

requirements(::MinLift) = (Minimum(),)

function lift(::MinLift, g::CertificateGraph)
    _check_lift_size(g, "min lift", big(2)^n_nodes(g) - 1)

    n = n_nodes(g)
    letters = sort(alphabet(g))
    index = successors(letter_graph(g))
    masks = collect(_masks(n))

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

simulation(::MinLift, G::CertificateGraph, H::CertificateGraph; optimizer = nothing) =
    simulation_relation(G, H)

"""
    MaxLift()

Nodes are the nonempty subsets; `(A, B, i)` is an edge when every node of `B`
is reached by an `i`-edge from `A` (Debauche, Della Rossa & Jungers, Def. 9).
The dual of [`MinLift`](@ref) (Debauche, Lemma 7.45), valid for templates
closed under [`Maximum`](@ref); its simulation is the relation on the dual
graphs, complete for them (Debauche, Thm. 8.5).
"""
const MaxLift = DualLift{MinLift}

MaxLift() = DualLift(MinLift())
