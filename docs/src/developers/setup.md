# Set up

Julia ≥ 1.10. CI tests 1.10 and the current release.

## Clone and instantiate

```
git clone https://github.com/dionysos-dev/PathCompleteCertificates.jl.git
cd PathCompleteCertificates.jl
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project=test -e 'using Pkg; Pkg.instantiate()'
```

`Manifest.toml` is deliberately untracked — a library must not pin its own resolution, so each
clone resolves for itself. The single exception is `repeatability/`, where a pinned manifest is the
entire point.

## Run the tests

**Do not run the whole suite for every change.** Prefer the narrowest scope that can fail:

**1. The file you touched, on its own.** Every test file is a self-contained module and *must* be
runnable standalone:

```
julia --project=test test/graphs/predicates.jl
```

Each file opens with

```julia
import PathCompleteCertificates
include(joinpath(dirname(dirname(pathof(PathCompleteCertificates))), "test", "testsetup.jl"))
```

which brings in `Test`, the `PCC` alias and the shared fixtures. Add file-specific imports after
that include. If a file is *not* standalone-runnable, that is a bug in the file — fix it by adding
the missing import.

**2. The fast subset.**

```
julia --project -e 'using Pkg; Pkg.test(; test_args = ["--fast"])'
```

Skips suites tagged `:slow` in `test/runtests.jl` — the SDP- and LP-heavy synthesis tests. The
driver prints per-file timings and a slowest-first summary, so a suite that has quietly become
expensive is easy to spot and tag.

**3. The full gate, before committing.**

```
julia --project -e 'using Pkg; Pkg.test()'
```

!!! warning "The fast subset can report green on a broken change"
    Anything whose only coverage lives in a `:slow` suite is invisible to `--fast` — and the
    synthesis tests, which are where most regressions will surface, are exactly those. Run the
    full gate before opening a pull request.

New test files go in the `TEST_FILES` list in `test/runtests.jl`, with `:slow` if they belong there.

## Format — required before every commit

```
julia -e 'using JuliaFormatter; format(".")'
```

CI fails on any diff. The rules are in `.JuliaFormatter.toml`; the settings themselves matter less
than having them fixed, so the style stops being something anyone argues about. Most consequential:
`always_use_return = true`, so every function ends with an explicit `return`.

## Build the documentation

```
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

`makedocs` runs with `checkdocs = :all`: **every exported symbol needs a docstring** or the build
fails. That is deliberate. The tool paper has six pages including references, so it cannot explain
the package — these docs have to.

Do not commit the `docs/Project.toml` changes that `Pkg.develop` produces.

## Continuous integration

| Workflow | What it gates |
| :-- | :-- |
| `ci.yml` | Test matrix on 1.10 and current; `ci-ok` aggregates it into one stable check |
| `format_check.yml` | Fails on any JuliaFormatter diff |
| `aqua.yml` | Type piracy, method ambiguities, stale dependencies |
| `documentation.yml` | Builds and deploys the docs |
| `blob-size-guard.yml` | Rejects any pull request adding a file over 5 MB |
| `doc-preview-cleanup.yml` | Deletes a pull request's docs preview when it closes |

The last two exist from the first commit rather than as an afterthought. A blob committed once
lives in the history of every clone forever, even if a later commit deletes it, and stale docs
previews accumulate in `gh-pages` until they dominate what a clone transfers. Both are cheap to
prevent and expensive to undo — undoing them means rewriting history on a live repository.
