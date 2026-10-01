```@meta
CurrentModule = PathCompleteCertificates
```

# Bibliography

Grouped by what each paper underwrites in the code, since that is usually how
you arrive: reading a predicate or a template, wanting its source. Every
definition and theorem number quoted in the manual was read in the paper it is
attributed to.

## The framework

[ahmadi2014joint](@cite) introduced path-complete graph Lyapunov functions and
the joint-spectral-radius bound they give. Its Definitions 2.1 and 2.2 are the
expanded form of a graph with words on its edges, [`expanded_form`](@ref), and
what path-completeness means for one.

[philippe2017path](@cite) is the authority for [Path-complete graphs](@ref):
Def. II.1 is [`is_path_complete`](@ref), Def. III.2 is [`is_complete`](@ref)
and [`is_co_complete`](@ref), and Cor. III.3 with Thm. III.8 are what
[`common`](@ref) dispatches on. Its Thm. IV.4 is the linear program of
[`conic_witness`](@ref).

[philippe2019complete](@cite) is the template-free ordering by simulation,
[`simulation`](@ref): Def. 3.1 defines it and Thm. 3.5 shows it characterises
the order that holds for every template.

[philippe2016stability](@cite) is constrained switching: the system's
automaton as the language a graph must read, decided by
`is_path_complete(graph, automaton)` and seeded by [`seed`](@ref). Its Def. 2
is [`ProductLift`](@ref) and its Def. 3 is [`PathDependentLift`](@ref).

## Template sources

[athanasopoulos2019polyhedral](@cite) is [`PolyhedralTemplate`](@ref), the
symmetric ``2n``-face form, facets fixed, weights solved for.

[`ConicPolyhedralTemplate`](@ref), the free-facet form, is **not yet
published**; it is under submission. There is deliberately no entry for it,
rather than a citation to the nearest published neighbour that would credit the
wrong result.

[`QuadraticTemplate`](@ref) and [`LinearCopositiveTemplate`](@ref) are standard
and have no single source. [`DualCopositiveTemplate`](@ref) is Def. 2.30 of
[debauche2024thesis](@cite).

[parrilo2008approximation](@cite) is [`SumOfSquaresTemplate`](@ref): the
sum-of-squares relaxation of the joint spectral radius, whose bound tightens
monotonically with the degree.

## Problem sources

[anand2024barrier](@cite) is [`SafetyProblem`](@ref).
[anand2025completeness](@cite) is its follow-up on ordering barriers, not
implemented here.

[ninite2026path](@cite) is [`OptimalControlProblem`](@ref), including the
``S = P^{-1}``, ``Y = KS`` substitution.

[`StabilityProblem`](@ref) is [ahmadi2014joint](@cite) directly.

## Sources for lifts and duality

[debauche2021comparison](@cite) defines a lift as any map on graphs preserving
path-completeness ([`AbstractLift`](@ref), its Def. 5), validity as the
guarantee of no worse a bound ([`is_valid`](@ref), Def. 6), and the sum, min,
max and composition lifts ([`SumLift`](@ref), [`MinLift`](@ref),
[`MaxLift`](@ref), [`CompositionLift`](@ref); Defs. 8, 9 and 10).

[debauche2024thesis](@cite) supplies the rest of [Duality](@ref): the dual
graph (Def. 6.3), the dual certificate (Lemma 6.25), the dual lift (Def. 7.4)
and its validity (Prop. 7.5), the max lift as the dual of the min lift
(Lemma 7.45), the backward composition lift (Def. 7.61) as the dual of the
forward one (Prop. 7.64), and the validity of the min lift for the copositive
template without closure (Thm. 7.43).

[athanasopoulos2019polyhedral](@cite) gives the four partial lifts,
[`ForwardEdgeSplit`](@ref), [`BackwardEdgeSplit`](@ref),
[`ForwardEdgeProduct`](@ref) and [`BackwardEdgeProduct`](@ref), Defs. 4 to 7.

[jongeneel2025ordering](@cite) is the `T`-fold [`CompositionLift`](@ref),
Def. III.1, and the reason it needs invertible dynamics.

[abate2026categorical](@cite) rederives the min, max and sum lifts from the
algebraic theory of each operation; its Example III.23 relates its sum lift to
[`SumLift`](@ref). [wintenberg2026complete](@cite) corrects the composition
lifts and is not yet available.

## Sources for comparing graphs

[debauche2023ordering](@cite) proves the linear program complete for
templates closed under addition, Thm. 2, and its five graphs are
[Comparing graphs: which one is better?](@ref).

[debauche2024thesis](@cite) characterises the order for `min`-closed and
`max`-closed templates by the simulation of the min and max lifts (Thms. 8.1
and 8.5), which [`simulation_relation`](@ref) decides without building them,
and shows that complete graphs buy nothing over one node for `min`-closed
templates (Cor. 7.53), which is [`simplify`](@ref).

## Sources for refinement

[ninite2026lifting](@cite) is [`refine`](@ref): the forward lift at a node
(Def. 3), the tight subgraph (Def. 4), and the optimality certificate
[`is_jsr_exact`](@ref) (Thm. 4).

## All references

```@bibliography
```
