# Numerical experiments

Scripts that reproduce the numerical results of the HSCC'27 tool paper. They run in their own
environment, which adds a solver and the sum-of-squares packages to the package of this
repository:

```
julia --project=numerical_experiments -e 'using Pkg; Pkg.instantiate()'
julia --project=numerical_experiments numerical_experiments/templates_jsr.jl
```

| Script | Result |
| :-- | :-- |
| `templates_jsr.jl` | Table of upper bounds on the JSR: five templates on the common graph and the De Bruijn graphs of order 1 and 3, on the pair of Section 5.2 |

Times depend on the machine and the solver version; the bounds should match the paper to the
digits shown. Results go under `numerical_experiments/results/`, which is ignored by git.
