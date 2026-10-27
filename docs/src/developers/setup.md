# Set up

Working on the package needs Julia 1.10 or later and git. This page sets up
the three environments, the package, its tests and its documentation, and
says how to run the tests, format the code and build the documentation.

## Clone and instantiate

```
git clone https://github.com/dionysos-dev/PathCompleteCertificates.jl.git
cd PathCompleteCertificates.jl
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project=test -e 'using Pkg; Pkg.instantiate()'
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
```

`Manifest.toml` is not tracked, so each clone resolves for itself. When
`Pkg.test()` reports a dependency missing from the manifest, delete the
manifest of the environment that failed, root, `test/` or `docs/`, and resolve
again. The docs environment reaches the package through a relative `[sources]`
entry; do not `Pkg.develop` it.

## Run the tests

Every test file is standalone. Run the narrowest scope that can fail, and the
whole suite before opening a pull request.

```
julia --project=test test/graphs/path_completeness.jl                # one file
julia --project -e 'using Pkg; Pkg.test(; test_args = ["--fast"])'   # skips the :slow suites
julia --project -e 'using Pkg; Pkg.test()'                           # everything
```

The `:slow` suites are the ones that solve programs, and most regressions
surface there, so a change is not tested until they pass. A new test file goes
in `TEST_FILES` in `test/runtests.jl`, tagged `:slow` if it solves.

While iterating, keep one Julia session open with Revise and `include` the
file you are working on; a cold start costs about half a minute.

## Format

Required before every commit; CI fails on any diff. The rules are in
`.JuliaFormatter.toml`.

```
julia -e 'using JuliaFormatter; format(".")'
```

## Build the documentation

```
julia --project=docs docs/make.jl                          # everything, a few minutes
PCC_SKIP_LITERATE=true julia --project=docs docs/make.jl   # skips the tutorials
```

The build executes every code block of the manual and every tutorial under
`docs/src/examples/`. With the tutorials skipped, a tutorial page not already
generated is dropped from the navigation, so run a full build before opening
a pull request.

Docstrings are checked twice. Nothing is exported, so `test/docstrings.jl` fails
on any name reachable as `PathCompleteCertificates.name` without one. And the
build fails on a docstring that no `@autodocs` block under
`docs/src/reference/` picks up, so a new file in `src/` needs a `Pages` entry
there.

## Continuous integration

| Workflow | Gates |
| :-- | :-- |
| `ci.yml` | the tests on Julia 1.10 and the current release |
| `format_check.yml` | the formatter |
| `aqua.yml` | type piracy, method ambiguities, stale dependencies |
| `documentation.yml` | the docs build and its deployment |
| `blob-size-guard.yml` | no file over 5 MB |
| `doc-preview-cleanup.yml` | removes a pull request's docs preview when it closes |
| `TagBot.yml` | tags each release once it is registered |
