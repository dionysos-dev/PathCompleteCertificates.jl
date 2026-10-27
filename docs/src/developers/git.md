# Git workflow

`master` moves only through pull requests; a direct push is rejected.

## The loop

```
git checkout master
git pull --ff-only origin master
git checkout -b <initials>/<short-description>

# work, then
julia -e 'using JuliaFormatter; format(".")'
julia --project -e 'using Pkg; Pkg.test()'

git add <the files of this change>
git commit -m "ADD graphs: indexed path-completeness predicate"
git push -u origin <initials>/<short-description>
```

Open the pull request from the link the push prints.

## Commit messages

```
ACTION module: description
```

Lowercase, no trailing period, at most 60 characters, and no `Co-Authored-By`
line.

| Action | Meaning |
| :-- | :-- |
| `ADD` | new feature |
| `IMP` | improvement |
| `FIX` | bug fix |
| `REF` | refactor, no behavior change |
| `REM` | removal |
| `MOV` | move or rename |
| `REV` | revert |

The module is the directory touched: `graphs`, `systems`, `templates`,
`problems`, `lifts`, `refinements`, `common`, `test`, `docs`, `examples` for
`docs/src/examples/`, and `meta` for configuration, CI and tooling.

```
ADD problems: optimal control edge inequality
FIX graphs: path-completeness on an empty alphabet
IMP meta: one actions/checkout version across workflows
```

## One commit per change

A bug fix and an unrelated improvement are two commits, even in one pull
request. For a wide rename, port the tests first, untouched, then rename the
code against them: renamed on both sides at once, a mistake can pass every
test.

## Never committed

`Manifest.toml`, any file over 5 MB, and experiment output; `.gitignore` lists
the usual kinds. A blob committed once stays in the history of every clone.
