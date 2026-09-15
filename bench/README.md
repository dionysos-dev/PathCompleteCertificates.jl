# Benchmarks

The refinement loop is the performance-critical path: it generates and tests thousands of
candidate graphs, so `is_path_complete` and `determinize` are the two operations that decide
whether the headline feature is usable.

## First benchmark to land here

The graph-layer spike: implement `de_bruijn_graph`, `is_path_complete` and `determinize`
twice — once on `HybridSystems.GraphAutomaton` + `MetaGraphsNext`, once on a plain indexed
in-house type — and compare over a De Bruijn family for `M ∈ {3,4}`, `k ∈ 3..6`.

Measure the **loop, not the primitives**: build 1000 random candidate graphs over the alphabet
and reject the non-path-complete ones. That is the shape of the refinement inner loop, and it
exercises the short-circuit behaviour on the mix of complete and incomplete graphs that
refinement actually produces.

Decision rule, fixed in advance: within ~2× the ecosystem version wins on integration grounds;
beyond ~5× the package owns an indexed type; in between, take the ecosystem version.

Keep the benchmark after the decision, so it can be re-run when either dependency moves.
