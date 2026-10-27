# Adding a tutorial

A tutorial is a Julia file in `docs/src/examples/`, rendered into the
Tutorials section by [Literate.jl](https://github.com/fredrikekre/Literate.jl)
and executed by the docs build, so a broken tutorial fails the build. Each
tutorial solves one problem from start to end.

## The shape of a file

```julia
# # Title of the tutorial
#
# A paragraph saying what this shows and why someone would read it.

import PathCompleteCertificates as PCC
import Clarabel

# Prose is a `# ` comment between code blocks.

A = [[0.5 0.0; 0.0 0.25]]
problem = PCC.StabilityProblem(PCC.switched_system(A))

# The last expression of a block is what the page shows, so end a block with
# the value worth seeing rather than printing it.

PCC.certify(PCC.QuadraticTemplate(), PCC.de_bruijn(1, 1), problem; optimizer = Clarabel.Optimizer)
```

- The `# # Title` line is the sidebar entry; `docs/make.jl` reads it from the
  file, so the filename stays lowercase.
- `# ` starts prose, `##` a comment kept inside a code block, `#-` separates
  two code blocks, and a line ending in `#src` is dropped from the page.
- End a block with the value, not a `println`.
- Admonitions, `@ref` and `@cite` work in the prose.
- To draw a graph, include `docs/graph_drawing.jl`, as the manual pages do.

## Wiring it in

Add the file's basename to `ORDER` in `docs/make.jl` to place it in the
reading order. A tutorial missing from `ORDER` is appended at the end with a
notice.

## Running it

```
julia --project=docs docs/src/examples/stability.jl
```

The docs environment carries the solvers and Plots; the package depends on
neither, and its tests on the solvers only. The tutorials use Clarabel, and a
setting a solver needs is set in the tutorial: `optimal_control.jl` disables
Clarabel's chordal decomposition, which fails on its model.
