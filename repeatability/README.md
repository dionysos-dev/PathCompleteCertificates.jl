# Repeatability Evaluation Package

Scaffolded now, filled as results appear. For an HSCC **tool paper** the REP is required, not
encouraged, and it is the single most common reason such artifacts fail evaluation — so it is
a deliverable with its own deadline, not packaging done the week before submission.

## What goes here

- `run.jl` — **one** script, no manual steps, that reproduces every number in the paper.
- `Manifest.toml` — pinned. This is the **only** place in the repository a `Manifest.toml` is
  tracked; everywhere else a library must not pin its own resolution.
- `README.md` — this file, eventually carrying the exact invocation and expected output.

## Rules the evaluator imposes

- **Open solvers only.** An artifact that needs a Mosek licence cannot be evaluated. Clarabel
  and HiGHS are native Julia and free.
- **Budget for the evaluator's patience.** If the full benchmark takes hours, ship a reduced
  default that finishes in minutes and a flag for the full run. An artifact that times out is
  treated the same as one that fails.
- **Test it on a clean machine** — not one that happens to have the right Julia version and a
  warm depot.
