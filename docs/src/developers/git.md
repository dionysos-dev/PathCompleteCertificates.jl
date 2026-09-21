# Git workflow

`master` is protected by a repository ruleset: **direct pushes are rejected**, force pushes and
branch deletion are blocked. Every change goes through a pull request. This is not advisory — the
push fails with `GH013: Changes must be made through a pull request`.

## The loop

```
git checkout master
git pull --ff-only origin master
git checkout -b <initials>/<short-description>

# ... work ...

julia -e 'using JuliaFormatter; format(".")'          # required
julia --project -e 'using Pkg; Pkg.test()'            # the full gate, not --fast

git add <only the files of this change>
git commit -m "ADD graphs: indexed path-completeness predicate"
git push -u origin <initials>/<short-description>
```

Then open the pull request from the link the push prints.

Branch names: `jc/stable-format-check`, `ln/optimal-control-objective`. Initials plus what the
branch does.

## Commit messages

```
[ACTION] module: description
```

- **description** — concise, lowercase, no trailing period, ≤ 60 characters.
- Do **not** add a `Co-Authored-By` line.

| Action | Meaning |
| :----- | :------ |
| `ADD`  | new feature |
| `IMP`  | improvement to an existing feature |
| `FIX`  | bug fix |
| `REF`  | refactor (no behaviour change) |
| `REM`  | removal |
| `MOV`  | move / rename |
| `REV`  | revert |

**Module** is the touched subsystem, inferred from the paths: `graphs`, `templates`, `problems`,
`systems`, `aggregation`, or `test` / `docs`. Use `examples` for a change confined to
`docs/src/examples/`, which is where the runnable scripts live.
Repository configuration, CI and tooling are `meta`.

Examples:

```
ADD problems: optimal control edge constraint
FIX graphs: path-completeness on an empty alphabet
IMP meta: one actions/checkout version across workflows
```

## One commit per logical change

Split when changes are independent — a bug fix and an unrelated improvement are two commits, even
in one pull request. Keep as one when everything serves a single purpose.

This matters more than it sounds for wide changes. A rename applied to both the code and its tests
in a single commit can be **wrong in a self-consistent way**: swap two functions on both sides and
every test still passes. Port the tests first, untouched, then rename the code against them.

## Do not commit

- **Large files.** `blob-size-guard` rejects anything over 5 MB in a pull request, and `.gitignore`
  covers the usual offenders (`*.jld2`, `*.bson`, video). A blob committed once lives in the history
  of every clone forever, even if a later commit deletes it.
- **`Manifest.toml`**.
- **`plan.md`.** The working plan is deliberately untracked: it carries candid assessments of
  neighbouring projects and of how to approach their maintainers, which has no business in a public
  repository. What belongs to everyone goes in `docs/` or `CLAUDE.md`.

## If a push to master is rejected

That is the ruleset doing its job. Move the commit onto a branch:

```
git branch <initials>/<description>     # keep the commit
git reset --hard origin/master          # put master back
git checkout <initials>/<description>
git push -u origin <initials>/<description>
```
