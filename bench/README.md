# Benchmarks

One script per instance from the literature, each printing what the paper reports so the two
can be read side by side. They are not tests: a solver, tie-breaking or a tolerance can move a
step count, and the claim each script checks is stated in its header. Run them with an
environment that carries a solver, `docs/` or `test/`:

```
julia --project=docs bench/athanasopoulos2019.jl
```

| Script | Instance | Claim |
| :-- | :-- | :-- |
| `athanasopoulos2019.jl` | Athanasopoulos & Jungers, CDC 2019, Example 2 | the four partial lifts at every tight edge, best candidate kept, prove stability of a two-mode 3-D system on the fixed-facet polyhedral template |

Results go under `bench/results/`, which is ignored by git.
