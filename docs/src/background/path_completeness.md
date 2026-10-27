```@meta
CurrentModule = PathCompleteCertificates
```

# Deciding path-completeness

## The subset construction

Start from the set of all nodes. Reading a mode ``i`` maps a set of nodes to
the set of nodes reached from it by an edge reading ``i``. A graph is
path-complete exactly when the empty set is never reached
([abate2026succinct](@cite), Prop. 3.1): a word that cannot be read leads to
the empty set, and any word that leads to it cannot be read.

[`is_path_complete`](@ref) explores the sets reachable from the set of all
nodes. Their number can grow exponentially with the number of nodes: deciding
path-completeness is PSPACE-complete in general, as recalled in
[abate2026succinct](@cite).

## Cheaper sufficient conditions

- On a **complete** graph, every node has an outgoing edge for every mode, so
  a nonempty set never maps to the empty set.
- On a **co-complete** graph, every node has an incoming edge for every mode,
  so the set of all nodes maps to itself.

Both conditions are checked node by node, and [`is_path_complete`](@ref) tries
them first.

## Words and duals

A graph with words on its edges is path-complete exactly when its expanded
graph is, by definition ([ahmadi2014joint](@cite), Def. 2.2), and
[`expanded_form`](@ref) builds that graph. The dual graph, with every edge
reversed, is path-complete exactly when the graph is
([debauche2024thesis](@cite), Prop. 6.6).
