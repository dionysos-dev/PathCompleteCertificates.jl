import HybridSystems

const _HS = HybridSystems

# The only file that uses `HybridSystems` graphs directly. Every other file
# goes through the functions defined here (`nodes`, `edges`, `label`,
# `add_edge!`, ...). These functions also accept a `WordGraph`, so the rest of
# the package handles both kinds of graph the same way.

"""
    WordGraph(n_nodes)

A labelled graph whose edges carry words, finite sequences of modes. Safety,
optimal control and [`common`](@ref) accept it only when every word is a single
mode.
"""
struct WordGraph{A <: _HS.GraphAutomaton}
    automaton::A
    words::Dict{Int, Vector{Int}}
end

WordGraph(n_nodes::Integer) =
    WordGraph(_HS.GraphAutomaton(n_nodes), Dict{Int, Vector{Int}}())

"""
    CertificateGraph

A graph a certificate is built on: a `HybridSystems.GraphAutomaton`, one mode
per edge, or a [`WordGraph`](@ref), one word per edge.
"""
const CertificateGraph = Union{_HS.GraphAutomaton, WordGraph}

_automaton(graph::_HS.GraphAutomaton) = graph
_automaton(graph::WordGraph) = graph.automaton

"""
    empty_graph(n_nodes)

A `HybridSystems.GraphAutomaton` with `n_nodes` nodes and no edge, to be filled
with [`add_edge!`](@ref), one mode per edge.
"""
empty_graph(n_nodes::Integer) = _HS.GraphAutomaton(n_nodes)

# An empty graph of the same kind as `graph`.
_empty_like(::_HS.GraphAutomaton, n_nodes::Integer) = _HS.GraphAutomaton(n_nodes)
_empty_like(::WordGraph, n_nodes::Integer) = WordGraph(n_nodes)

"""
    add_edge!(graph, source, dest, label)

Add an edge from `source` to `dest` reading `label`, a mode or a vector of
modes, and return it. Only a [`WordGraph`](@ref) accepts a word of several
modes.
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

The number of nodes of `graph`.
"""
n_nodes(graph::CertificateGraph) = _HS.nstates(_automaton(graph))

"""
    n_edges(graph)

The number of edges of `graph`.
"""
n_edges(graph::CertificateGraph) = _HS.ntransitions(_automaton(graph))

"""
    nodes(graph)

The nodes of `graph`.
"""
nodes(graph::CertificateGraph) = _HS.states(_automaton(graph))

"""
    edges(graph)

The edges of `graph`.
"""
edges(graph::CertificateGraph) = _HS.transitions(_automaton(graph))

"""
    has_edge(graph, edge) -> Bool

Whether `edge` belongs to `graph`.
"""
has_edge(graph::CertificateGraph, edge::_HS.GraphTransition) =
    _HS.has_transition(_automaton(graph), edge)

"""
    source(edge)

The source node of an edge.
"""
source(edge::_HS.GraphTransition) = edge.edge.src

"""
    dest(edge)

The destination node of an edge.
"""
dest(edge::_HS.GraphTransition) = edge.edge.dst

"""
    label(graph, edge)

The label of `edge` in `graph`: a mode, or a word on a
[`WordGraph`](@ref).
"""
label(graph::_HS.GraphAutomaton, edge::_HS.GraphTransition) = _HS.event(graph, edge)
label(graph::WordGraph, edge::_HS.GraphTransition) = graph.words[edge.id]

"""
    letters(label)

The modes a label reads, in order.
"""
letters(mode::Integer) = (mode,)
letters(word::AbstractVector{<:Integer}) = word

_word_length(graph::CertificateGraph, edge::_HS.GraphTransition) =
    length(letters(label(graph, edge)))

"""
    has_words(graph) -> Bool

Whether some edge of `graph` reads a word of two or more modes.
"""
has_words(::_HS.GraphAutomaton) = false
has_words(graph::WordGraph) = any(word -> length(word) > 1, values(graph.words))

function _require_one_mode_per_edge(graph::CertificateGraph, what::AbstractString)
    has_words(graph) && throw(
        ArgumentError(
            "$what needs one mode per edge; expand the word graph with " *
            "`expanded_form` first",
        ),
    )

    return nothing
end

function _check_node(graph::CertificateGraph, node::Integer)
    1 <= node <= n_nodes(graph) || throw(ArgumentError("node $node is outside the graph"))
    return nothing
end

"""
    outgoing_edges(graph, node)
    outgoing_edges(graph, node, mode)

The edges leaving `node`, optionally only those whose label is the single mode
`mode`; an edge reading a word of several modes is never among them.
"""
function outgoing_edges(graph::CertificateGraph, node::Integer)
    _check_node(graph, node)
    return collect(_HS.out_transitions(_automaton(graph), node))
end

function outgoing_edges(graph::CertificateGraph, node::Integer, mode::Integer)
    return [edge for edge in outgoing_edges(graph, node) if _reads(graph, edge, mode)]
end

"""
    incoming_edges(graph, node)
    incoming_edges(graph, node, mode)

The edges entering `node`, optionally only those whose label is the single mode
`mode`; an edge reading a word of several modes is never among them.
"""
function incoming_edges(graph::CertificateGraph, node::Integer)
    _check_node(graph, node)
    return collect(_HS.in_transitions(_automaton(graph), node))
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
    alphabet(graph)

The distinct modes appearing on the edges of `graph`, possibly fewer than the
system's.
"""
alphabet(graph::CertificateGraph) =
    unique(mode for edge in edges(graph) for mode in letters(label(graph, edge)))

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

function _successors(graph::_HS.GraphAutomaton)
    index = Dict{Tuple{Int, Int}, Vector{Int}}()

    for edge in edges(graph)
        push!(get!(index, (source(edge), label(graph, edge)), Int[]), dest(edge))
    end

    return index
end

function _predecessors(graph::_HS.GraphAutomaton)
    index = Dict{Tuple{Int, Int}, Vector{Int}}()

    for edge in edges(graph)
        push!(get!(index, (dest(edge), label(graph, edge)), Int[]), source(edge))
    end

    return index
end

# `graph` as a `GraphAutomaton`, whose labels are modes. A `GraphAutomaton` is
# returned as is; a `WordGraph` whose words are single modes is rebuilt with
# those modes as labels; any longer word throws an error naming `what`, the
# caller.
_letter_graph(graph::_HS.GraphAutomaton, ::AbstractString) = graph

function _letter_graph(graph::WordGraph, what::AbstractString)
    _require_one_mode_per_edge(graph, what)

    result = _HS.GraphAutomaton(n_nodes(graph))

    for edge in edges(graph)
        add_edge!(result, source(edge), dest(edge), only(label(graph, edge)))
    end

    return result
end
