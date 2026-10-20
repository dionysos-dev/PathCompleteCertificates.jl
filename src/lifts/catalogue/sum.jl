"""
    SumLift(T)
    SumLift()

The `T`-sum lift: nodes are the multisets of `T` nodes, with an `i`-edge from
`P` to `Q` when the `i`-edges from `P` to `Q` admit a perfect matching.
`SumLift()` stands for every `T` at once and is never built:
`simulation(SumLift(), G, H; optimizer)` decides it
[debauche2024thesis; Thm. 7.35 and Cor. 8.11](@cite) and returns an integer
matrix `C` such that `C·V` is a certificate on `H` whenever `V` is one on `G`
[philippe2019path; Def. IV.2 and Thm. IV.4](@cite). Requires
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

    modes = alphabet(g)
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
    _proves_infeasible(model) && return nothing
    JuMP.is_solved_and_feasible(model; allow_almost = true) || error(
        "the linear program deciding the sum lift ended with status " *
        "$(JuMP.termination_status(model)), so the order is unknown",
    )

    # The rounded matrix is what is returned, so it is what is checked. The
    # simplest rounding that passes is kept.
    solution = JuMP.value.(C)
    for tol in (1e-4, 1e-6, 1e-8)
        integers = _integerise(solution; tol)
        integers !== nothing && _satisfies(G, H, optimizer, integers) && return integers
    end

    return error(
        "the linear program is feasible, but its solution did not round to an " *
        "integer matrix that still satisfies it",
    )
end

# Only a proof of infeasibility means there is no simulation. The objective is
# bounded below, so infeasible-or-unbounded is infeasible.
const _INFEASIBLE =
    (JuMP.MOI.INFEASIBLE, JuMP.MOI.ALMOST_INFEASIBLE, JuMP.MOI.INFEASIBLE_OR_UNBOUNDED)

_proves_infeasible(model::JuMP.Model) = JuMP.termination_status(model) in _INFEASIBLE

# Whether the integer matrix `C`, row sums included, satisfies the program.
function _satisfies(G, H, optimizer, C::AbstractMatrix{<:Integer})
    all(>(0), sum(C; dims = 2)) || return false

    check, _ = _sum_program(G, H, optimizer, C)
    JuMP.optimize!(check)
    return JuMP.is_solved_and_feasible(check; allow_almost = true)
end

# The program of [philippe2019path, Def. IV.2], over the multipliers alone when `C`
# is given; `nothing` when some mode of `H` is read nowhere in `G`.
function _sum_program(G, H, optimizer, C)
    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    if C === nothing
        C = JuMP.@variable(model, [1:n_nodes(H), 1:n_nodes(G)], lower_bound = 0)
        JuMP.@constraint(model, [h in 1:n_nodes(H)], sum(C[h, :]) >= 1)

        # Generic positive costs, so that the solution is one vertex, rational
        # with small denominators, and not the inner point of the solution set
        # that an interior-point solver returns for a feasibility problem.
        JuMP.@objective(model, Min, sum(_generic_weights(size(C)...) .* C))
    end

    for letter in alphabet(H)
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

# Distinct weights in [1, 2), deterministic and with no simple relation between
# them, so that ties between vertices are unlikely.
_generic_weights(m::Integer, n::Integer) =
    [1 + mod(h * MathConstants.golden + g * sqrt(2), 1) for h in 1:m, g in 1:n]

# The smallest integer matrix proportional to `C`, each entry read as the
# simplest fraction within `tol` of its ratio to the largest; `nothing` when it
# does not fit in `Int`.
function _integerise(C::AbstractMatrix{<:Real}; tol::Real)
    scaled = C ./ maximum(C)
    rationals = [x < tol ? big(0) // 1 : rationalize(BigInt, x; tol = tol) for x in scaled]
    integers = numerator.(rationals .* lcm(denominator.(rationals)...))

    # The largest entry scales to 1, so the gcd is positive.
    integers = integers .÷ gcd(integers...)
    return all(<=(typemax(Int)), integers) ? Int.(integers) : nothing
end
