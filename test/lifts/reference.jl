module TestLiftReference

# The four partial lifts of Athanasopoulos & Jungers (CDC 2019, Defs. 4-7),
# ported line for line from the reference implementation in Diptarko Roy's
# repository, Python on edge lists, and compared with ours at every edge of
# five graphs. Agreement is exact wherever the paper defines the lift. What the
# paper leaves open is pinned here as well: a node left without edges, which
# its degree assumptions exclude, is deleted; and a locus of several edges is
# the lift applied edge by edge, with the self-loop last.

using Test
using HybridSystems
import PathCompleteCertificates as PCC

# --- The reference, as written. An nfa is a list of (source, word, destination).

function partial_T_lift(nfa, s, σ, d)
    new = empty(nfa)
    for (q0, w, q1) in nfa
        push!(new, (q0, w, q1))
        q0 == d && push!(new, (s, vcat(σ, w), q1))
    end
    deleteat!(new, findfirst(==((s, σ, d)), new))
    return new
end

function partial_T_star_lift(nfa, s, σ, d)
    new = empty(nfa)
    for (q0, w, q1) in nfa
        push!(new, (q0, w, q1))
        q1 == s && push!(new, (q0, vcat(w, σ), d))
    end
    deleteat!(new, findfirst(==((s, σ, d)), new))
    return new
end

function partial_P_lift(nfa, s, σ, d)
    new_d = maximum(e[1] for e in nfa) + 1
    new = empty(nfa)
    for (q0, w, q1) in nfa
        push!(new, (q0, w, q1))
        q0 == d && push!(new, (new_d, w, q1))
    end
    deleteat!(new, findfirst(==((s, σ, d)), new))
    push!(new, (s, σ, new_d))
    return new
end

function partial_P_star_lift(nfa, s, σ, d)
    new_s = maximum(e[1] for e in nfa) + 1
    new = empty(nfa)
    for (q0, w, q1) in nfa
        push!(new, (q0, w, q1))
        q1 == s && push!(new, (q0, w, new_s))
    end
    deleteat!(new, findfirst(==((s, σ, d)), new))
    push!(new, (new_s, σ, d))
    return new
end

const REFERENCE = Dict(
    "T" => partial_T_lift,
    "T*" => partial_T_star_lift,
    "P" => partial_P_lift,
    "P*" => partial_P_star_lift,
)

const OURS = Dict(
    "T" => PCC.ForwardEdgeProduct(),
    "T*" => PCC.BackwardEdgeProduct(),
    "P" => PCC.BackwardEdgeSplit(),
    "P*" => PCC.ForwardEdgeSplit(),
)

const KINDS = ["T", "T*", "P", "P*"]

# --- Reading graphs as the reference does.

nfa(g) = [
    (PCC.source(e), collect(Int, PCC.letters(PCC.label(g, e))), PCC.dest(e)) for
    e in PCC.edges(g)
]

edgeset(g) = Set(nfa(g))

triple(g, e) = (PCC.source(e), collect(Int, PCC.letters(PCC.label(g, e))), PCC.dest(e))

reference(kind, g, e) = Set(REFERENCE[kind](nfa(g), triple(g, e)...))

ours(kind, g, e) = edgeset(PCC.graph(OURS[kind](g, [e])))

# The paper assumes a second outgoing edge at the source of a P*-lifted edge
# and a second incoming one at the destination of a P-lifted edge.
function in_domain(kind, g, e)
    kind == "P*" && return PCC.outdegree(g, PCC.source(e)) >= 2
    kind == "P" && return PCC.indegree(g, PCC.dest(e)) >= 2
    return true
end

# --- Fixtures: three graphs of the HSCC 2023 capsule, one with a self-loop on
# every node, the one-node graph, and a word graph.

function graph(edges, n)
    g = GraphAutomaton(n)
    for (a, b, l) in edges
        add_transition!(g, a, b, l)
    end
    return g
end

const G1 = graph(
    [
        (1, 2, 1),
        (2, 1, 1),
        (1, 3, 1),
        (3, 1, 2),
        (1, 4, 2),
        (4, 1, 1),
        (1, 5, 2),
        (5, 1, 2),
    ],
    5,
)
const G2 = graph(
    [
        (1, 3, 2),
        (1, 4, 2),
        (2, 1, 1),
        (2, 2, 1),
        (3, 3, 2),
        (3, 4, 2),
        (4, 2, 1),
        (4, 1, 1),
    ],
    4,
)
const G4 = graph(
    [
        (1, 2, 1),
        (2, 4, 1),
        (3, 2, 1),
        (4, 3, 1),
        (4, 5, 1),
        (5, 1, 1),
        (1, 4, 2),
        (1, 3, 2),
        (2, 1, 2),
        (3, 2, 2),
        (4, 5, 2),
        (5, 1, 2),
    ],
    5,
)
const LOOPS =
    graph([(1, 1, 1), (1, 2, 2), (2, 1, 1), (2, 2, 2), (2, 3, 1), (3, 1, 2), (3, 3, 2)], 3)
const ONE = PCC.seed(OneStateAutomaton(2))
const WORDS = PCC.graph(PCC.ProductLift(2)(G2))

const GRAPHS = [("G1", G1), ("G2", G2), ("G4", G4), ("loops", LOOPS), ("one", ONE)]

@testset "every partial lift agrees with the reference where the paper defines it" begin
    for (name, g) in GRAPHS, kind in KINDS, e in PCC.edges(g)
        in_domain(kind, g, e) || continue
        @test ours(kind, g, e) == reference(kind, g, e)
    end

    # Self-loops are among the edges above; make sure of it.
    @test any(e -> PCC.source(e) == PCC.dest(e), PCC.edges(LOOPS))
    @test all(e -> in_domain("P*", LOOPS, e), PCC.edges(LOOPS))
end

@testset "the products concatenate words the same way on a word graph" begin
    for kind in ("T", "T*"), e in PCC.edges(WORDS)
        @test ours(kind, WORDS, e) == reference(kind, WORDS, e)
    end
end

# Delete a node and renumber the ones above it, as our lift numbers survivors.
function without(edges, node)
    shift(k) = k > node ? k - 1 : k
    return Set(
        (shift(q0), w, shift(q1)) for (q0, w, q1) in edges if q0 != node && q1 != node
    )
end

@testset "outside the paper's assumption the reference leaves a dead node; we delete it" begin
    # Nodes 2 to 5 of G1 have one incoming and one outgoing edge.
    outside = [
        (kind, e) for kind in ("P", "P*") for e in PCC.edges(G1) if !in_domain(kind, G1, e)
    ]
    @test length(outside) == 8

    for (kind, e) in outside
        s, d = PCC.source(e), PCC.dest(e)
        dead = kind == "P*" ? s : d
        theirs = reference(kind, G1, e)

        # No path runs through the node the reference leaves behind.
        if kind == "P*"
            @test !any(x -> x[1] == dead, theirs)
        else
            @test !any(x -> x[3] == dead, theirs)
        end

        @test without(theirs, dead) == ours(kind, G1, e)
    end
end

# The reference applied at the edges of a locus one after the other, each on
# the graph the previous one produced.
function sequential(kind, g, locus)
    current = nfa(g)
    for e in locus
        current = REFERENCE[kind](current, triple(g, e)...)
    end
    return Set(current)
end

@testset "a locus at a surviving node is the reference edge by edge, loop last" begin
    # Node 2 of LOOPS keeps (2, 3, 1); the locus is its other edge and its loop.
    across = only(filter(e -> PCC.dest(e) == 1, PCC.outgoing_edges(LOOPS, 2, 1)))
    loop = only(PCC.outgoing_edges(LOOPS, 2, 2))
    @test PCC.source(across) == 2 && PCC.dest(across) == 1
    @test PCC.source(loop) == PCC.dest(loop) == 2

    loop_last = [across, loop]
    @test edgeset(PCC.graph(PCC.ForwardEdgeSplit()(LOOPS, loop_last))) ==
          sequential("P*", LOOPS, loop_last)

    # The reference is order dependent at a loop: the other order differs.
    @test sequential("P*", LOOPS, [loop, across]) != sequential("P*", LOOPS, loop_last)

    # Without a loop the order only renumbers the copies, and ours -- which
    # numbers them in locus order -- agrees with the reference in either.
    out = PCC.outgoing_edges(G4, 1)
    @test length(out) == 3
    for order in (out[1:2], reverse(out[1:2]))
        @test edgeset(PCC.graph(PCC.ForwardEdgeSplit()(G4, order))) ==
              sequential("P*", G4, order)
    end
end

end # module
