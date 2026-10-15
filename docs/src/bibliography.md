```@meta
CurrentModule = PathCompleteCertificates
```

# Bibliography

What the package takes from each paper. Every definition and theorem
number quoted in the manual was read in the paper it is attributed to.

## Path-complete graphs and stability

| | |
| :-- | :-- |
| [ahmadi2014joint](@cite) | path-complete graph Lyapunov functions and the bound on the joint spectral radius: [`StabilityProblem`](@ref), [`is_path_complete`](@ref), [`expanded_form`](@ref) |
| [philippe2019path](@cite) | complete and co-complete graphs, [`is_complete`](@ref) and [`is_co_complete`](@ref), the common function each licenses, [`common`](@ref), and the linear program of [`SumLift`](@ref)`()` |
| [philippe2016stability](@cite) | [`common_graph`](@ref), [`ProductLift`](@ref) and [`PathDependentLift`](@ref), and the backward split that takes the De Bruijn hierarchy one order up |

## The templates

| | |
| :-- | :-- |
| [athanasopoulos2019polyhedral](@cite) | `ParallelFacesPolyhedralTemplate`, fixed facets and solved-for weights, and the four partial lifts that are [`OutSplitLift`](@ref), [`InSplitLift`](@ref), [`ForwardProductLift`](@ref) and [`BackwardProductLift`](@ref) |
| [parrilo2008approximation](@cite) | `SetProg.PolySet` |
| [debauche2024thesis](@cite) | `DualCopositiveTemplate`, Def. 2.30 |

`SetProg.Ellipsoid` and `LinearCopositiveTemplate` are
standard. `ConicPolyhedralTemplate` is under submission and has no
entry yet.

## Safety and optimal control

| | |
| :-- | :-- |
| [anand2024barrier](@cite) | [`SafetyProblem`](@ref), path-complete barrier functions |
| [ninite2026path](@cite) | [`OptimalControlProblem`](@ref), including the substitution that makes it convex |

## Comparing graphs

| | |
| :-- | :-- |
| [philippe2019complete](@cite) | the order that holds for every template, decided by a [`simulation`](@ref) |
| [debauche2021comparison](@cite) | the order ``G \le_V H``, lifts and their validity, [`is_valid`](@ref), and the [`SumLift`](@ref), [`MinLift`](@ref), [`MaxLift`](@ref) and [`CompositionLift`](@ref) |
| [debauche2022necessary](@cite) | the min and max lifts decided by a simulation relation, without building them |
| [debauche2023ordering](@cite) | the linear program of the sum lift proved complete, and the five graphs of [Comparing graphs: five graphs, three templates](@ref) |
| [debauche2024thesis](@cite) | [Duality](@ref) throughout: the dual graph, system, template, certificate and lift; the De Bruijn graphs; [`BackwardCompositionLift`](@ref); the validity of the min lift for the copositive template |
| [jongeneel2025ordering](@cite) | the ``T``-fold [`CompositionLift`](@ref), the counterexample to its completeness, and its use as a step of [`refine`](@ref) |

## Refining a graph

| | |
| :-- | :-- |
| [ninite2026lifting](@cite) | [`TightestNodeSplitting`](@ref), the default algorithm of [`refine`](@ref); the forward lift at a node, [`OutSplitLift`](@ref); the tight subgraph, [`tight_subgraph`](@ref), and the optimality certificate [`is_jsr_exact`](@ref) |
| [athanasopoulos2019polyhedral](@cite) | [`BestOfTightEdgeLifts`](@ref), the procedure of its Example 2 |

The lifts themselves come from [athanasopoulos2019polyhedral](@cite) and
[philippe2016stability](@cite), listed above.

## Related work

[abate2026categorical](@cite) rederives the min, max and sum lifts from the
algebra of each operation. [anand2025completeness](@cite) orders barrier
certificates, and [wintenberg2026complete](@cite) gives a complete ordering
for composition-closed templates, where the composition lift is sufficient
only. [abate2026succinct](@cite) designs the graph and its certificate
together with an SMT solver. None of these is implemented here.

## All references

```@bibliography
```
