```@meta
CurrentModule = PathCompleteCertificates
```

# Extending the package

The code of a new problem, lift or refinement strategy is one file in the
`catalogue/` folder of its directory, and a new template is a SetProg family.
The functions to implement are listed in [Conventions](@ref). This page says
where each piece goes, and what to wire in around it. Each extension closes a
gap of [What works with what](@ref), the map of what the package covers.

## Every extension

1. Write the file in `src/<directory>/catalogue/`, named after the type without
   the directory's suffix.
2. Include it in `src/PathCompleteCertificates.jl`.
3. Give every public name a docstring, and add the file to the `Pages` list of
   its page under `docs/src/reference/`, or the docs build fails.
4. Add a test file under `test/<directory>/`, `test/problems/` for a
   template, and list it in `TEST_FILES` in `test/runtests.jl`.
5. Update [What works with what](@ref), its tables and the gap the extension
   closes, and present the extension on the manual page of its kind:
   [Choosing a template](@ref), [Lifts](@ref) or
   [Refining the graph](@ref).

## A template

A template is a SetProg family, a subtype of `SetProg.AbstractVariable`, whose
set variables and inclusion constraints SetProg provides. A constructor that
builds it is a file in `src/templates/catalogue/`, like `quadratic.jl`. A
family new to the package also needs its methods, in two files:

- `src/problems/gauges.jl`: `add_function_variables!`, `add_normalization!`,
  `add_decrease!`, `homogeneity_degree` and `solution_value`, and
  `decrease_slack` for [`refine`](@ref) to run on it.
- `src/problems/sets.jl`: `is_applicable` (the systems it applies to),
  `is_closed_under` (the lifts valid for it), `reindex` (per-node data), and
  `has_dual` and `dual` when it has a dual.

Stability then accepts the new family without change. Safety needs its
methods of `_safety_family`, `_safety_multiplier` and `_safety_normalization!`,
in `src/problems/catalogue/safety.jl`. Optimal control with fixed gains needs
the family in `_FixedGainControlFamily` and a method of
`_fixed_gain_control_case`, in
`src/problems/catalogue/fixed_gain_optimal_control.jl`. Both write their
conditions as SetProg inclusions (see [Conditions as set inclusions](@ref)).

## A problem

A subtype of `AbstractProblem` holding the system, and a certificate type
holding a `CertificateData` and what the problem certifies. Implement
`optimization_model`, and `certify`, which returns the best certificate on the
graph. Write the edge inequality once, in a private `_edge_decrease` used both
to build the model and to measure the slacks, as stability and safety do. For
[`refine`](@ref) to run on it, define `objective` and `edge_slacks`,
`_refinable(::YourProblem) = true`, and let `certify` take `rtol`, the
relative tolerance on the objective.

## A lift

A subtype of `AbstractLift` with the `lift` methods its definition gives it: on
the whole graph, at edges, or at a node. Declare its `requirements`, the
operations a template must be closed under for the lift to be valid. For
[`BestOfTightEdgeLifts`](@ref) to use it, give it the method at edges, and
define `_changes` to skip the edges where it changes nothing.

## A refinement strategy

A subtype of `AbstractRefinementStrategy` that implements `next_graph`, and
`initial_graph` when it does not start from the common graph.
[`refine`](@ref) runs the loop, the solves and the stopping rules.
