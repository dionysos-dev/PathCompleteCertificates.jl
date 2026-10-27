```@meta
CurrentModule = PathCompleteCertificates
```

# Bibliography

The manual cites each result where it uses it. This page says, paper by
paper, what the package takes from each.

## Certificates

| Paper | What the package takes from it |
| :-- | :-- |
| [ahmadi2014joint](@cite) | path-complete graphs, and the bound on the joint spectral radius: [`StabilityProblem`](@ref), [`is_path_complete`](@ref), [`expanded_form`](@ref) |
| [philippe2019path](@cite) | complete and co-complete graphs, and the common function: [`common`](@ref) |
| [anand2024barrier](@cite) | path-complete barrier functions: [`SafetyProblem`](@ref) |
| [ninite2026path](@cite) | path-complete optimal control: [`OptimalControlProblem`](@ref) |
| [abate2026succinct](@cite) | the characterization of path-completeness by the subset construction |

## Templates

| Paper | What the package takes from it |
| :-- | :-- |
| [athanasopoulos2019polyhedral](@cite) | [`ParallelFacesPolyhedralTemplate`](@ref) |
| [parrilo2008approximation](@cite) | [`SumOfSquaresTemplate`](@ref) |
| [debauche2024thesis](@cite) | [`DualCopositiveTemplate`](@ref) |

[`QuadraticTemplate`](@ref) and [`LinearCopositiveTemplate`](@ref) are
standard. [`ConicPolyhedralTemplate`](@ref) is not published yet.

## Lifts and graphs

| Paper | What the package takes from it |
| :-- | :-- |
| [athanasopoulos2019polyhedral](@cite) | the partial lifts: [`OutSplitLift`](@ref), [`InSplitLift`](@ref), [`ForwardProductLift`](@ref), [`BackwardProductLift`](@ref) |
| [philippe2016stability](@cite) | [`PathDependentLift`](@ref) and [`ProductLift`](@ref) |
| [philippe2019complete](@cite) | the order between graphs for every template: [`simulation`](@ref) |
| [debauche2021comparison](@cite) | the order for a given template, lifts and their validity: [`is_valid`](@ref), [`MinLift`](@ref), [`MaxLift`](@ref), [`SumLift`](@ref) |
| [debauche2022necessary](@cite) | the min and max lifts decided by a relation |
| [debauche2023ordering](@cite) | the sum lift decided by a linear program, and the graphs of [Compare two graphs](@ref) |
| [debauche2024thesis](@cite) | duality, the De Bruijn graphs, and the composition lifts: [`CompositionLift`](@ref), [`BackwardCompositionLift`](@ref) |
| [jongeneel2025ordering](@cite) | the composition lifts of any length |

## Refinement

| Paper | What the package takes from it |
| :-- | :-- |
| [ninite2026lifting](@cite) | [`TightestNodeSplitting`](@ref), the tight subgraph and [`is_jsr_exact`](@ref) |
| [athanasopoulos2019polyhedral](@cite) | [`BestOfTightEdgeLifts`](@ref) |

## Related work

Not implemented here: [abate2026categorical](@cite) derives the min, max and
sum lifts from the algebra of each operation; [anand2025completeness](@cite)
orders barrier certificates; [wintenberg2026complete](@cite) orders graphs for
templates closed under composition; [abate2026succinct](@cite) designs the
graph and its certificate together with an SMT solver.

## All references

```@bibliography
```
