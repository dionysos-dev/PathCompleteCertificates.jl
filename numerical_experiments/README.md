# Numerical experiments

Scripts that reproduce the numerical results of the HSCC'27 tool paper. They run in their own
environment, which adds a solver, the sum-of-squares packages and Plots to the package of this
repository:

```
julia --project=numerical_experiments -e 'using Pkg; Pkg.instantiate()'
julia --project=numerical_experiments numerical_experiments/three_problems.jl
julia --project=numerical_experiments numerical_experiments/templates_jsr.jl
julia --project=numerical_experiments numerical_experiments/refinement.jl
```

| Script | Result |
| :-- | :-- |
| `three_problems.jl` | Section 5.1, figure "One graph, one template, three problems": stability, safety and optimal control on the De Bruijn graph of order 1 with the quadratic template |
| `templates_jsr.jl` | Section 5.1, table of templates and graphs: upper bounds on the JSR, and smallest certified unsafe radius for the pair scaled by 1/2, with five templates on the common graph and the De Bruijn graphs of order 1 and 3 |
| `refinement.jl` | Section 5.2, figure "Automatic refinement": the two refinement algorithms against the De Bruijn hierarchy, and the last refined graph |

The environment takes `SetProg.jl` at its `main` branch, which the polyhedral safety templates
need until its next release.

Times depend on the machine and the solver version; the bounds should match the paper to the
digits shown. Results, figures included, go under `numerical_experiments/results/`, which is
ignored by git.
