import JuMP

"""
    SumLift(T)
    SumLift()

The `T`-sum lift: nodes are the multisets of `T` original nodes, `(P, Q, i)`
is an edge when the `i`-edges from `P` to `Q` admit a perfect matching
(Debauche, Della Rossa & Jungers, Def. 8; Debauche, Prop. 7.16), and the node
function is the sum over the multiset. Without `T` it is the sum lift over
every size (Debauche, Della Rossa & Jungers, HSCC 2023, Def. 8; Abate,
Debauche, Giacobbe, Myers & Roy, Ex. III.23), which cannot be built but whose
simulation is decided by a linear program.

Valid for templates closed under [`Addition`](@ref); self-dual (Debauche,
Prop. 7.13). `simulation(SumLift(), G, H; optimizer)` returns a nonnegative
integer matrix `C`, every row summing to at least one, such that `C·V` is a
certificate on `H` whenever `V` is one on `G` (Philippe, Athanasopoulos,
Angeli & Jungers, Def. IV.2 and Thm. IV.4). It is complete: feasible exactly
when some `T`-sum lift of `G` simulates `H` (Debauche, Thm. 7.35 and
Cor. 8.11). The solver's matrix is rounded to integers and checked against the
program again before it is returned. `simulation(SumLift(T), G, H)` builds the
`T`-th level and returns a map into multisets, which exists for some `T`
whenever the program is feasible (HSCC 2023, Lemma 3). `origins` are the
multisets as sorted vectors.
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

    letters = sort(alphabet(g))
    index = _successors(_letter_graph(g))
    multisets = _multisets(n_nodes(g), L.terms)

    lifted = empty_graph(length(multisets))

    for (p, P) in enumerate(multisets), (q, Q) in enumerate(multisets), letter in letters
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
    G, H = _letter_graph(G), _letter_graph(H)

    program = _sum_program(G, H, optimizer, nothing)
    program === nothing && return nothing

    model, C = program
    JuMP.optimize!(model)
    JuMP.termination_status(model) in _FEASIBLE_TERMINATION_STATUSES || return nothing

    # What is returned is the rounded matrix, so it is the rounded matrix that
    # is checked against the program.
    integers = _integerise(JuMP.value.(C))
    check, _ = _sum_program(G, H, optimizer, integers)
    JuMP.optimize!(check)
    JuMP.termination_status(check) in _FEASIBLE_TERMINATION_STATUSES || error(
        "the linear program is feasible, but its solution did not round to an " *
        "integer matrix that still satisfies it",
    )

    return integers
end

# The program of Philippe et al., Def. IV.2: over the matrix `C` when `nothing`
# is given, over the multipliers alone when `C` is. `nothing` when some mode of
# `H` is read nowhere in `G`.
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
    common = gcd(integers...)

    return common == 0 ? integers : integers .÷ common
end
