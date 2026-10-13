_masks(n::Integer) = 1:(2 ^ n - 1)
_members(mask::Integer, n::Integer) =
    [node for node in 1:n if (mask >> (node - 1)) & 1 == 1]

"""
    MinLift()

Nodes are the nonempty subsets, with an `i`-edge from `A` to `B` when every
node of `A` has an `i`-edge into `B`. Requires [`Minimum`](@ref), except for
linear copositive norms on positive systems
[debauche2024thesis; Thm. 7.43](@cite); its simulation is the greatest
simulation relation [debauche2024thesis; Thm. 8.1](@cite).
"""
struct MinLift <: AbstractLift end

requirements(::MinLift) = (Minimum(),)

function lift(::MinLift, g::CertificateGraph)
    _check_lift_size(g, "min lift", big(2)^n_nodes(g) - 1)

    n = n_nodes(g)
    modes = alphabet(g)
    index = _successors(_letter_graph(g, "the min lift"))
    masks = collect(_masks(n))

    reach = Dict{Tuple{Int, Int}, Int}()
    for ((node, letter), targets) in index
        reach[(node, letter)] = sum(1 << (target - 1) for target in unique(targets))
    end

    lifted = empty_graph(length(masks))

    for (a, A) in enumerate(masks), letter in modes
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
    _simulation_relation(_letter_graph(G, "the min lift"), _letter_graph(H, "the min lift"))
