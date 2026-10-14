# Adding an example

An example is a Julia file in `docs/src/examples/`, rendered into the manual by
[Literate.jl](https://github.com/fredrikekre/Literate.jl) and executed by the
docs build, so a broken example fails the build.

## The shape of a file

```julia
# # Title of the example
#
# A paragraph saying what this shows and why someone would read it.

import PathCompleteCertificates as PCC
import Clarabel
import SetProg

# Prose is a `# ` comment between code blocks.

A = [[0.5 0.0; 0.0 0.25]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

# The last expression of a block is what the page shows, so end a block with
# the value worth seeing rather than printing it.

PCC.jsr_bound(SetProg.Ellipsoid(symmetric = true), PCC.de_bruijn(1, 1), problem; optimizer = Clarabel.Optimizer)
```

- The `# # Title` line is the sidebar entry; `docs/make.jl` reads it from the
  file, so the filename stays lowercase.
- `# ` starts prose, `##` a comment kept inside a code block, `#-` separates
  two code blocks, and a line ending in `#src` is dropped from the page.
- End a block with the value, not a `println`.
- Admonitions, `@ref` and `@cite` work in the prose.

## Wiring it in

Add the file's basename to `ORDER` in `docs/make.jl` to place it in the
reading order. An example missing from `ORDER` is appended at the end with a
notice.

## Running it

```
julia --project=docs docs/src/examples/stability.jl
```

The docs environment carries the solver and Plots; the package and its tests
depend on neither. The examples use Clarabel, and a setting a solver needs is
set in the example: `optimal_control.jl` disables Clarabel's chordal
decomposition, which fails on its model.
