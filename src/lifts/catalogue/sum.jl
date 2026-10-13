import JuMP

"""
    SumLift(T)
    SumLift()

The `T`-sum lift: nodes are the multisets of `T` nodes, with an `i`-edge from
`P` to `Q` when the `i`-edges from `P` to `Q` admit a perfect matching.
`SumLift()` stands for every `T` at once and is never built:
`simulation(SumLift(), G, H; optimizer)` decides it
[debauche2024thesis; Thm. 7.35 and Cor. 8.11](@cite) and returns an integer
matrix `C` such that `C·V` is a certificate on `H` whenever `V` is one on `G`
[philippe2017path; Def. IV.2 and Thm. IV.4](@cite). Requires
[`Addition`](@ref).
"""
struct SumLift{T <: Union{Nothing, Int}} <: AbstractLift
    terms::T

    SumLift() = new{Nothing}(nothing)

    function SumLift(terms::Integer)
        terms >= 1 || throw(ArgumentError("the number of terms must be positive"))
        return new{Int}(terms)
    end
end

requirements(::SumLift) = (Addition(),)

dual(L::SumLift) = L

lift(::SumLift{Nothing}, ::CertificateGraph) = throw(
    ArgumentError(
        "the sum lift over every size is not finite; `SumLift(T)` builds its T-th level",
    ),
)

function lift(L::SumLift{Int}, g::CertificateGraph)
    _check_lift_size(g, "sum lift", binomial(big(n_nodes(g) + L.terms - 1), L.terms))

    modes = sort(alphabet(g))
    index = _successors(_letter_graph(g, "the sum lift"))
    multisets = _multisets(n_nodes(g), L.terms)

    lifted = empty_graph(length(multisets))

    for (p, P) in enumerate(multisets), (q, Q) in enumerate(multisets), letter in modes
        _has_perfect_matching(P, Q, letter, index) && add_edge!(lifted, p, q, letter)
    end

    return Lifted(lifted, multisets)
end

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

function simulation(
    ::SumLift{Nothing},
    G::CertificateGraph,
    H::CertificateGraph;
    optimizer = nothing,
)
    optimizer === nothing && throw(
        ArgumentError("the sum lift is decided by a linear program and needs an optimizer"),
    )
    G, H = _letter_graph(G, "the sum lift"), _letter_graph(H, "the sum lift")

    program = _sum_program(G, H, optimizer, nothing)
    program === nothing && return nothing

    model, C = program
    JuMP.optimize!(model)
    JuMP.is_solved_and_feasible(model; allow_almost = true) || return nothing

    # The rounded matrix is what is returned, so it is what is checked.
    integers = _integerise(JuMP.value.(C))
    check, _ = _sum_program(G, H, optimizer, integers)
    JuMP.optimize!(check)
    JuMP.is_solved_and_feasible(check; allow_almost = true) || error(
        "the linear program is feasible, but its solution did not round to an " *
        "integer matrix that still satisfies it",
    )

    return integers
end

# The program of [philippe2017path, Def. IV.2], over the multipliers alone when `C`
# is given; `nothing` when some mode of `H` is read nowhere in `G`.
function _sum_program(G, H, optimizer, C)
    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    if C === nothing
        C = JuMP.@variable(model, [1:n_nodes(H), 1:n_nodes(G)], lower_bound = 0)
        JuMP.@constraint(model, [h in 1:n_nodes(H)], sum(C[h, :]) >= 1)
    end

    for letter in union(alphabet(G), alphabet(H))
        edges_G = [e for e in edges(G) if label(G, e) == letter]
        edges_H = [e for e in edges(H) if label(H, e) == letter]

        isempty(edges_H) && continue
        isempty(edges_G) && return nothing

        S_G, D_G = _incidences(G, edges_G)
        S_H, D_H = _incidences(H, edges_H)

        K = JuMP.@variable(model, [1:length(edges_H), 1:length(edges_G)], lower_bound = 0)
        JuMP.@constraint(model, S_H * C .>= K * S_G)
        JuMP.@constraint(model, D_H * C .<= K * D_G)
    end

    return model, C
end

function _incidences(g, edge_list)
    S = zeros(Int, length(edge_list), n_nodes(g))
    D = zeros(Int, length(edge_list), n_nodes(g))

    for (k, edge) in enumerate(edge_list)
        S[k, source(edge)] = 1
        D[k, dest(edge)] = 1
    end

    return S, D
end

function _integerise(C::AbstractMatrix{<:Real}; tol = 1e-8)
    clipped = map(c -> c < tol ? zero(c) : c, C)
    scaled = clipped ./ maximum(clipped)
    rationals = rationalize.(Int, scaled; tol = tol)
    denominators = lcm(denominator.(rationals)...)
    integers = Int.(rationals .* denominators)
    divisor = gcd(integers...)

    return divisor == 0 ? integers : integers .÷ divisor
end
