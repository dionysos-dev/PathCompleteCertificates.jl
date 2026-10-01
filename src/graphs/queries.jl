import HybridSystems

const _HS = HybridSystems

# The adapter. Every other file reads and writes graphs through the functions
# here, never through `HybridSystems` internals: it is what lets the backing
# store change in one place, and what lets a graph carry words on its edges
# without the rest of the package noticing.

"""
    WordGraph(n_nodes)

A labelled graph whose edges carry **words**: finite sequences of modes, a mode
being a word of length one.

Built like a `GraphAutomaton`, with [`add_edge!`](@ref) taking a vector of modes
for the label. A word edge `(s, d, w)` imposes one inequality, on the product of
the modes along `w`, and costs no node — which is what the edge products of
[`ForwardEdgeProduct`](@ref) buy. Every query of this file accepts one;
[`label`](@ref) returns the word.

Path-completeness of a word graph is decided on its [`expanded_form`](@ref).
Stability accepts word graphs; safety, optimal control and [`common`](@ref) do
not, since they need the state at every step.
"""
struct WordGraph{A <: _HS.GraphAutomaton}
    automaton::A
    words::Dict{Int, Vector{Int}}
end

WordGraph(n_nodes::Integer) =
    WordGraph(_HS.GraphAutomaton(n_nodes), Dict{Int, Vector{Int}}())

"""
    CertificateGraph

The graph types a certificate is built on: a `HybridSystems.GraphAutomaton`,
whose labels are modes, or a [`WordGraph`](@ref), whose labels are words.

The certificate graph and the system's own automaton share the first type on
purpose — one vocabulary — so the argument name says which is wanted: `graph`
is the certificate's, `system` carries its own.
"""
const CertificateGraph = Union{_HS.GraphAutomaton, WordGraph}

_automaton(graph::_HS.GraphAutomaton) = graph
_automaton(graph::WordGraph) = graph.automaton

"""
    empty_graph(n_nodes)

A `GraphAutomaton` with `n_nodes` nodes and no edge. Add edges with
[`add_edge!`](@ref); for a graph whose edges read words, start from
[`WordGraph`](@ref)`(n_nodes)` instead.
"""
empty_graph(n_nodes::Integer) = _HS.GraphAutomaton(n_nodes)

# An empty graph of the same kind as `graph`: the lifts and the tight subgraph
# rebuild a graph with the labels it had. Dispatch keeps the result type
# concrete, which a keyword switch would not.
_empty_like(::_HS.GraphAutomaton, n_nodes::Integer) = _HS.GraphAutomaton(n_nodes)
_empty_like(::WordGraph, n_nodes::Integer) = WordGraph(n_nodes)

"""
    add_edge!(graph, source, dest, label)

Add an edge from `source` to `dest` reading `label`, a mode or a vector of
modes, and return it.

A `GraphAutomaton` takes a mode, or a vector of length one; a
[`WordGraph`](@ref) takes either.
"""
function add_edge!(graph::_HS.GraphAutomaton, s::Integer, d::Integer, mode::Integer)
    return _HS.add_transition!(graph, s, d, mode)
end

function add_edge!(
    graph::_HS.GraphAutomaton,
    s::Integer,
    d::Integer,
    word::AbstractVector{<:Integer},
)
    length(word) == 1 || throw(
        ArgumentError(
            "a GraphAutomaton carries one mode per edge; use a WordGraph for the " *
            "word $word",
        ),
    )

    return add_edge!(graph, s, d, only(word))
end

function add_edge!(
    graph::WordGraph,
    s::Integer,
    d::Integer,
    word::AbstractVector{<:Integer},
)
    isempty(word) && throw(ArgumentError("an edge must read at least one mode"))

    # The automaton's own label is never read; the word is.
    transition = _HS.add_transition!(graph.automaton, s, d, Int(first(word)))
    graph.words[transition.id] = collect(Int, word)

    return transition
end

add_edge!(graph::WordGraph, s::Integer, d::Integer, mode::Integer) =
    add_edge!(graph, s, d, [mode])

"""
    n_nodes(graph)

Return the number of nodes of `graph`.
"""
n_nodes(graph::CertificateGraph) = _HS.nstates(_automaton(graph))

"""
    n_edges(graph)

Return the number of edges of `graph`.
"""
n_edges(graph::CertificateGraph) = _HS.ntransitions(_automaton(graph))

"""
    nodes(graph)

Return the nodes of `graph`.
"""
nodes(graph::CertificateGraph) = _HS.states(_automaton(graph))

"""
    edges(graph)

Return the edges of `graph`.
"""
edges(graph::CertificateGraph) = _HS.transitions(_automaton(graph))

"""
    source(edge)

Return the source node of an edge.
"""
source(edge::_HS.GraphTransition) = edge.edge.src

"""
    dest(edge)

Return the destination node of an edge.
"""
dest(edge::_HS.GraphTransition) = edge.edge.dst

"""
    label(graph, edge)

Return the label of `edge` in `graph`: a mode on a `GraphAutomaton`, a word on a
[`WordGraph`](@ref). Read it with [`letters`](@ref) to treat both alike.

An edge carries its identifier but not its label, so the graph is required.
"""
label(graph::_HS.GraphAutomaton, edge::_HS.GraphTransition) = _HS.event(graph, edge)
label(graph::WordGraph, edge::_HS.GraphTransition) = graph.words[edge.id]

"""
    letters(label)

The modes a label reads, in order: `(i,)` for a mode `i`, the word itself for a
word. What makes a letter graph and a word graph answer the same code.
"""
letters(mode::Integer) = (mode,)
letters(word::AbstractVector{<:Integer}) = word

"""
    word_length(graph, edge)

The number of modes `edge` reads — one on a `GraphAutomaton`.
"""
word_length(graph::CertificateGraph, edge::_HS.GraphTransition) =
    length(letters(label(graph, edge)))

"""
    is_letter_graph(graph) -> Bool

Whether every edge of `graph` reads exactly one mode. Always true of a
`GraphAutomaton`; true of a [`WordGraph`](@ref) whose words all have length one.
"""
is_letter_graph(::_HS.GraphAutomaton) = true
is_letter_graph(graph::WordGraph) = all(word -> length(word) == 1, values(graph.words))

function _check_node(graph::CertificateGraph, node::Integer)
    1 <= node <= n_nodes(graph) || throw(ArgumentError("Node $node is outside the graph."))
    return nothing
end

"""
    outgoing_edges(graph, node)
    outgoing_edges(graph, node, mode)

The edges leaving `node`, optionally only those reading exactly `mode`.

Indexed through the backing graph's adjacency, so the cost is the degree, not
the edge count.
"""
function outgoing_edges(graph::CertificateGraph, node::Integer)
    _check_node(graph, node)
    return collect(_HS.out_transitions(_automaton(graph), node))
end

"""
    incoming_edges(graph, node)
    incoming_edges(graph, node, mode)

The edges entering `node`, optionally only those reading exactly `mode`.
"""
function incoming_edges(graph::CertificateGraph, node::Integer)
    _check_node(graph, node)
    return collect(_HS.in_transitions(_automaton(graph), node))
end

function outgoing_edges(graph::CertificateGraph, node::Integer, mode::Integer)
    return [edge for edge in outgoing_edges(graph, node) if _reads(graph, edge, mode)]
end

function incoming_edges(graph::CertificateGraph, node::Integer, mode::Integer)
    return [edge for edge in incoming_edges(graph, node) if _reads(graph, edge, mode)]
end

# Whether `edge` reads exactly the one-letter word `mode`.
function _reads(graph::CertificateGraph, edge::_HS.GraphTransition, mode::Integer)
    word = letters(label(graph, edge))
    return length(word) == 1 && first(word) == mode
end

"""
    out_neighbors(graph, node)

The nodes directly reachable from `node`, one entry per edge — so a node
reachable under two labels appears twice.
"""
out_neighbors(graph::CertificateGraph, node::Integer) =
    [dest(edge) for edge in outgoing_edges(graph, node)]

"""
    in_neighbors(graph, node)

The nodes with an edge into `node`, one entry per edge.
"""
in_neighbors(graph::CertificateGraph, node::Integer) =
    [source(edge) for edge in incoming_edges(graph, node)]

"""
    alphabet(graph)

The distinct modes appearing on the edges of `graph` — every letter of every
word — the switching alphabet it can read.

This is the alphabet the graph *uses*, which is not in general the system's.
A graph that never mentions a mode has a smaller alphabet and is not
path-complete for a system that has it, so pass the system's language
explicitly to [`is_path_complete`](@ref) rather than relying on this.
"""
function alphabet(graph::CertificateGraph)
    seen = Int[]

    for edge in edges(graph), mode in letters(label(graph, edge))
        mode in seen || push!(seen, mode)
    end

    return seen
end

"""
    words(graph)

The distinct labels on the edges of `graph`, each as the vector of modes it
reads.
"""
words(graph::CertificateGraph) =
    unique(collect(Int, letters(label(graph, edge))) for edge in edges(graph))

"""
    outgoing_alphabet(graph, node)

The distinct modes readable first from `node`: the first letter of every label
leaving it.
"""
outgoing_alphabet(graph::CertificateGraph, node::Integer) =
    unique(first(letters(label(graph, edge))) for edge in outgoing_edges(graph, node))

"""
    incoming_alphabet(graph, node)

The distinct modes read last on arrival at `node`: the last letter of every
label entering it.
"""
incoming_alphabet(graph::CertificateGraph, node::Integer) =
    unique(last(letters(label(graph, edge))) for edge in incoming_edges(graph, node))

"""
    outdegree(graph, node)

The number of edges leaving `node`.
"""
outdegree(graph::CertificateGraph, node::Integer) = length(outgoing_edges(graph, node))

"""
    indegree(graph, node)

The number of edges entering `node`.
"""
indegree(graph::CertificateGraph, node::Integer) = length(incoming_edges(graph, node))

"""
    successors(graph)

The adjacency of a letter graph as a dictionary from `(node, mode)` to the
destinations of the edges leaving `node` under `mode`.

Built once and passed around: the subset construction, the observer and the
simulation relation all read it, and asking [`outgoing_edges`](@ref) per pair
instead was measured at fifty times the cost of the predicate it served.
"""
function successors(graph::_HS.GraphAutomaton)
    index = Dict{Tuple{Int, Int}, Vector{Int}}()

    for edge in edges(graph)
        push!(get!(index, (source(edge), label(graph, edge)), Int[]), dest(edge))
    end

    return index
end

"""
    predecessors(graph)

The adjacency of a letter graph as a dictionary from `(node, mode)` to the
sources of the edges entering `node` under `mode`. The dual of
[`successors`](@ref).
"""
function predecessors(graph::_HS.GraphAutomaton)
    index = Dict{Tuple{Int, Int}, Vector{Int}}()

    for edge in edges(graph)
        push!(get!(index, (dest(edge), label(graph, edge)), Int[]), source(edge))
    end

    return index
end

"""
    letter_graph(graph)

The `GraphAutomaton` with the same nodes and edges as a [`WordGraph`](@ref)
whose words all have length one. Throws on a longer word — see
[`expanded_form`](@ref) for those.
"""
letter_graph(graph::_HS.GraphAutomaton) = graph

function letter_graph(graph::WordGraph)
    is_letter_graph(graph) ||
        throw(ArgumentError("the graph carries words longer than one mode; expand it"))

    result = _HS.GraphAutomaton(n_nodes(graph))

    for edge in edges(graph)
        add_edge!(result, source(edge), dest(edge), only(label(graph, edge)))
    end

    return result
end
