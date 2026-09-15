Commit the current changes following this project's commit convention.

## Message format

`[ACTION] module: description`

- **description** — concise, lowercase, no trailing period, ≤ 60 characters.
- Do **not** add a `Co-Authored-By` line.

### Actions

| Action | Meaning |
| :----- | :------ |
| `ADD`  | new feature |
| `IMP`  | improvement to an existing feature |
| `FIX`  | bug fix |
| `REF`  | refactor (no behaviour change) |
| `REM`  | removal |
| `MOV`  | move / rename |
| `REV`  | revert |

### Module

The subsystem the change belongs to, inferred from the touched paths:

- `src/graphs/` → `graphs`, `src/lifts/` → `lifts`, `src/templates/` → `templates`,
  `src/objectives/` → `objectives`, `src/synthesis/` → `synthesis`,
  `src/verification/` → `verification`, `src/sets/` → `sets`.
- `test/` → `test`, `docs/` → `docs`, `bench/` → `bench`,
  `repeatability/` → `repeatability`.
- Repo config / CI / tooling → `meta`.

Example: `ADD graphs: indexed path-completeness predicate`

## Steps

1. Re-read the **Git workflow** section of `CLAUDE.md` and honour it (never commit to
   `master` — branch first; format before committing).
2. `git status` — see the full working tree.
3. `git diff --cached` and `git diff` — review staged and unstaged changes.
4. Decide **one commit or several**. Split when changes are logically independent; keep as
   one when everything serves a single purpose.
5. For each commit: `git add` only the files of that logical unit, pick the `ACTION` and
   `module`, write the description, commit.
6. `git status` again to verify nothing is left behind.
