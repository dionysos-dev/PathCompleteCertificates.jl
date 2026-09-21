# Adding an example

Examples live in `docs/src/examples/` as plain Julia files and are rendered
into the manual by [Literate.jl](https://github.com/fredrikekre/Literate.jl).
The `.jl` file is the single source of truth: there is no parallel markdown to
keep in step, and **the docs build executes it**, so an example that breaks
fails CI rather than quietly going stale.

## The shape of a file

```julia
# # Title of the example
#
# A paragraph saying what this shows and why someone would read it.

import PathCompleteCertificates as PCC
import Clarabel

# Prose between code blocks is a `# ` comment. Everything else is code.

A = [[0.5 0.0; 0.0 0.25]]

# The last expression of a block is displayed, so end a block with the thing
# worth seeing rather than printing it.

PCC.jsr_bound(PCC.QuadraticTemplate(), PCC.de_bruijn(1, 1), problem; optimizer = Clarabel.Optimizer)
```

Four conventions, each with a reason:

- **The first `# # Title` line is the sidebar entry.** `docs/make.jl` reads it
  out of the file, which decouples the nav text from the filename — so
  filenames stay lowercase and space-free without the sidebar going with them.
- **End a block with the value, don't `println` it.** Documenter renders the
  last expression, including plots. A `println` produces less readable output
  and a stray `nothing`.
- **`##` is a code comment; `# ` is prose.** Literate strips one `#` when it
  emits code, so a comment you want to survive *inside* a code block needs two.
- **Use `#src` for lines that are only for running the file as a script.**
  They are dropped from the rendered page.

Admonitions work in the prose comments, and so do `@ref` and `@cite`:

```julia
# !!! warning "A bound is an upper bound"
#     `is_stable` returning `false` means no certificate was found in this
#     template on this graph. See [What works with what](@ref).
```

## Wiring it in

Nothing, usually. `docs/make.jl` picks up every `.jl` file in the directory.

To place it in the reading order rather than at the end, add its basename to
`ORDER` in `docs/make.jl`. An example not listed there is appended
alphabetically with an `@info` notice, and a stale entry in `ORDER` produces a
warning — so neither mistake is silent.

## Running it

```
julia --project=docs docs/src/examples/stability.jl
```

The docs environment carries Clarabel and Plots for exactly this. The package
itself depends on neither, and neither does the test environment CI
instantiates — a plotting dependency in the package would be a plotting
dependency for every user.

To build the docs without executing the examples — much faster while iterating
on prose:

```
PCC_SKIP_LITERATE=true julia --project=docs docs/make.jl
```

In that mode, pages whose markdown is not already in `docs/src/generated` are
dropped from the nav rather than breaking the build. Cross-references *into*
those pages will then fail, so run a full build before opening a pull request.

!!! note "Generated output is not committed"
    `docs/src/generated/` is gitignored. It is rebuilt from the `.jl` sources
    every time, which is what keeps the rendered numbers honest.

## Choosing a solver

Clarabel, unless it cannot do the job — it is open, it installs as an artifact,
and an example that needs a licence cannot be evaluated by anyone reading the
docs. Do not reach for Mosek.

Where a solver needs a specific setting to work, set it **in the example, with
a comment saying why**. `optimal_control.jl` disables Clarabel's chordal
decomposition because that pass has a bug on its model; the comment says so, so
the next person does not read the setting as a modelling choice.
