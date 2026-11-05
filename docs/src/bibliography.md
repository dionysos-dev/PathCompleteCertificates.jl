```@meta
CurrentModule = PathCompleteCertificates
```

# Bibliography

The manual cites each result where it uses it. This page says, paper by
paper, what the package takes from each.

## Certificates

| Paper | What the package takes from it |
| :-- | :-- |
| [ahmadi2014joint](@citet) | path-complete graphs, and the bound on the joint spectral radius: [`StabilityProblem`](@ref), [`is_path_complete`](@ref), [`expanded_form`](@ref) |
| [philippe2019path](@citet) | complete and co-complete graphs, and the common function: [`common`](@ref) |
| [anand2024barrier](@citet) | path-complete barrier certificates: [`SafetyProblem`](@ref) |
| [ninite2026path](@citet) | path-complete optimal control: [`OptimalControlProblem`](@ref) |
| [abate2026succinct](@citet) | the characterization of path-completeness by the subset construction |

## Templates

| Paper | What the package takes from it |
| :-- | :-- |
| [athanasopoulos2019polyhedral](@citet) | the two polyhedral parameterizations, by pairs of opposite vertices and by pairs of parallel faces, which [`PiecewiseLinearTemplate`](@ref) and its dual [`DualPiecewiseLinearTemplate`](@ref) extend to any partition into cones |
| [parrilo2008approximation](@citet) | [`SumOfSquaresTemplate`](@ref) |
| [debauche2021comparison](@citet) | the primal and dual linear copositive norms: [`LinearCopositiveTemplate`](@ref) and [`DualCopositiveTemplate`](@ref) |

[`QuadraticTemplate`](@ref) is standard. [`PiecewiseQuadraticTemplate`](@ref)
keeps the cones of [`PiecewiseLinearTemplate`](@ref), with a quadratic form on
each.

## Set programming

Every template is a family of sets of SetProg.jl, and every problem writes its
conditions as inclusions between the sets of the node functions, which
SetProg.jl reformulates for each family.

| Paper | What the package takes from it |
| :-- | :-- |
| [legat2019set](@citet), [legat2020set](@citet) | SetProg.jl: the set variables, the inclusion constraints and the families on which every template is built |
| [legat2023computation](@citet) | the reformulation of an inclusion for each family, imposed on the sets or on their polars, whichever keeps the family tractable |
| [gardner2013operations](@citet) | the polar ``L_\delta`` sum, with which [`OptimalControlProblem`](@ref) writes the Bellman inequality as an inclusion |
| [weisser2019polynomial](@citet) | SumOfSquares.jl, with which SetProg.jl imposes the conditions of [`SumOfSquaresTemplate`](@ref) and [`PiecewiseQuadraticTemplate`](@ref) |

## Lifts and graphs

| Paper | What the package takes from it |
| :-- | :-- |
| [athanasopoulos2019polyhedral](@citet) | the partial lifts: [`OutSplitLift`](@ref), [`InSplitLift`](@ref), [`ForwardProductLift`](@ref), [`BackwardProductLift`](@ref) |
| [philippe2016stability](@citet) | [`PathDependentLift`](@ref) and [`ProductLift`](@ref) |
| [philippe2019complete](@citet) | the order between graphs for every template: [`simulation`](@ref) |
| [debauche2021comparison](@citet) | the order for a given template, lifts and their validity: [`is_valid`](@ref), [`MinLift`](@ref), [`MaxLift`](@ref), [`SumLift`](@ref) |
| [debauche2022necessary](@citet) | the min and max lifts decided by a relation |
| [debauche2023ordering](@citet) | the sum lift decided by a linear program, and the graphs of [Compare two graphs](@ref) |
| [debauche2024thesis](@citet) | duality, the De Bruijn graphs, and the composition lifts: [`CompositionLift`](@ref), [`BackwardCompositionLift`](@ref) |
| [jongeneel2025ordering](@citet) | the composition lifts of any length |

## Refinement

| Paper | What the package takes from it |
| :-- | :-- |
| [ninite2026lifting](@citet) | [`TightestNodeSplitting`](@ref), the tight subgraph and [`is_jsr_exact`](@ref) |
| [athanasopoulos2019polyhedral](@citet) | [`BestOfTightEdgeLifts`](@ref) |

## Software

| Package | What the package takes from it |
| :-- | :-- |
| JuMP [lubin2023jump](@cite) | the modeling layer of every program, and the solvers it connects to |
| HybridSystems.jl [legat2025hybridsystems](@cite) | the representation of switched systems: [`switched_system`](@ref) |
| Clarabel [goulart2026clarabel](@cite) | the solver of the examples of this documentation |

## Related work

Not implemented here:

- [abate2026categorical](@citet) derives the min, max and sum lifts from the
  algebra of each operation.
- [anand2025completeness](@citet) orders barrier certificates.
- [wintenberg2026complete](@citet) orders graphs for templates closed under
  composition.
- [abate2026succinct](@citet) also designs the graph and its certificate
  together, with an SMT solver.
- [legat2020certifying](@citet) certifies the instability of switched systems
  with sums of squares, in SwitchOnSafety.jl.
- [rakovic2021minkowski](@citet) and [rakovic2025robust](@citet) write the
  Bellman equation of gauge costs with sets.
  [summers2013approximate](@citet) relaxes Bellman inequalities with sums of
  squares for discounted stochastic control, and
  [rantzer2000piecewise](@citet) bounds the cost of given control laws with
  piecewise quadratic functions in continuous time.

## All references

```@bibliography
```
