```@meta
CurrentModule = PathCompleteCertificates
```

# Extending the package

A new problem, lift or refinement algorithm is one file in the `catalogue/`
folder of its directory, and a new template is a SetProg family. The functions
to implement are listed in [Conventions](@ref); this page says where each piece
goes.

## Every extension

1. Write the file in `src/<directory>/catalogue/`, named after the type without
   the directory's suffix.
2. Include it in `src/PathCompleteCertificates.jl`.
3. Give every public name a docstring, and add the file to the `Pages` list of
   its page under `docs/src/reference/`, or the docs build fails.
4. Add a test file under `test/<directory>/`, and list it in `TEST_FILES` in
   `test/runtests.jl`.

## A template

Unlike the other extensions, a template is not a file in `catalogue/`: for
stability, it is a SetProg family, a subtype of `SetProg.AbstractVariable`,
whose set variables and inclusion constraints SetProg provides. The package
adds methods for it in two files:

- `src/problems/gauges.jl`: `add_function_variables!`, `add_normalization!`,
  `add_decrease!`, `homogeneity_degree` and `solution_value`, and
  `decrease_slack` for [`refine`](@ref) to run on it;
- `src/problems/sets.jl`: `is_applicable` (the systems it applies to),
  `is_closed_under` (the lifts valid for it) and `reindex` (per-node data).

Stability then accepts the new family without change; safety and optimal
control are written for the quadratic template.

## A problem

A subtype of `AbstractProblem` holding the system, and a certificate type
holding a `CertificateData` and what the problem certifies. Implement
`optimization_model`, and `certify`, which returns the best certificate on the
graph. Write the edge condition once, in a private `_edge_decrease` used both
to build the model and to measure the slacks. For [`refine`](@ref) to run on
it, define `objective` and `edge_slacks`, `_refinable(::YourProblem) = true`,
and let `certify` take `rtol`, the relative tolerance on the objective.

## A lift

A subtype of `AbstractLift` with the `lift` methods its definition gives it: on
the whole graph, at edges, or at a node. Declare its `requirements`, the
operations a template must be closed under for the lift to be valid. For
[`BestOfTightEdgeLifts`](@ref) to use it, define `_changes`, which says whether
the lift at an edge changes the graph.

## A refinement algorithm

A subtype of `AbstractRefinementAlgorithm` that implements `next_graph`, and
`initial_graph` when it does not start from the one-node graph.
[`refine`](@ref) runs the loop, the solves and the stopping rules.
