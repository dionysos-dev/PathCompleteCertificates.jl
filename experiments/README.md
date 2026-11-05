# Numerical experiments

Scripts that reproduce the numerical results of the HSCC'27 tool paper. They run in their own
environment, which adds the solvers, the sum-of-squares packages and Plots to the package of this
repository:

```
julia --project=experiments -e 'using Pkg; Pkg.instantiate()'
julia --project=experiments experiments/three_problems.jl
julia --project=experiments experiments/templates_jsr.jl
julia --project=experiments experiments/refinement.jl
```

| Script | Result |
| :-- | :-- |
| `three_problems.jl` | Section 5.1, figure "One graph, one template, three problems": stability, safety and optimal control on the De Bruijn graph of order 1 with the quadratic template |
| `templates_jsr.jl` | Section 5.1, table of templates and graphs: upper bounds on the JSR, and smallest certified unsafe radius for the pair scaled by 1/2, with six templates on the common graph and the De Bruijn graphs of order 1 and 3 |
| `refinement.jl` | Section 5.2, figure "Automatic refinement": the two refinement strategies against the De Bruijn hierarchy, and the last refined graph |

Times depend on the machine and the solver version. The bounds should match the paper to the
digits shown. Results, figures included, go under `experiments/results/`, which is
ignored by git.
