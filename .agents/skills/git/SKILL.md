---
name: Git
description: Prepare, review, and create Git commits in EllesmereUIExtend using Conventional Commits 1.0.0 and the required nameplates, questtracker, and shared scopes. Use when choosing commit messages, staging changes, or committing work.
---

# Git workflow

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
Read the repository's `AGENTS.md` and any applicable nested guidance.

## Safety and authorization

- Check `git status --short` and inspect the relevant diff before staging.
- Treat unfamiliar changes as user work. Never discard or overwrite them.
- Commit or push only when explicitly requested. A request to draft a message,
  create a skill, or review changes does not authorize a commit or push.
- Stage explicit paths for the requested work, not the entire working tree.
  Exclude unrelated user changes unless the user asks to include them.
- Do not amend commits, rewrite history, force-push, or run destructive Git
  commands without explicit authorization.

## Commit message format

```text
<type>(<scope>)[!]: <description>

[optional body]

[optional footer(s)]
```

- Use `feat` for new features and `fix` for bug fixes.
- Other appropriate types include `docs`, `test`, `refactor`, `perf`, `style`,
  `build`, `ci`, `chore`, and `revert`. These are permitted conventions, not
  additional types required by the specification.
- Use lowercase types and scopes, with no whitespace inside the parentheses.
- Write a concise description immediately after the colon and one space.
- Separate an optional body and footers with blank lines.
- Mark breaking changes with `!` immediately before the colon and/or an
  uppercase `BREAKING CHANGE: <description>` footer. Explain the breaking
  behavior; do not mark an ordinary internal change as breaking.

## Required scopes

Choose the scope from the actual changes included in the commit, not from the
branch name or the entire working tree.

| Changes included in the commit | Required scope |
| --- | --- |
| Only the Nameplates feature (`Nameplates/`) | `nameplates` |
| Only the QuestTracker feature (`QuestTracker/`) | `questtracker` |
| Any shared Core changes (`Core/`), including Core alone | `shared` |
| Both Nameplates and QuestTracker | `shared` |
| Core plus either or both features | `shared` |
| Repository-wide tooling, packaging, or guidance not specific to one feature | `shared` |

Feature-specific tests and documentation follow that feature's scope, even when
their files are outside its directory. Supporting documentation or tooling
changes do not turn a single-feature commit into a shared commit unless they
also change shared behavior or another feature.

If ownership is unclear, inspect the changes and ask before choosing a scope.
Prefer separate commits for unrelated work; do not split a cohesive cross-feature
change merely to avoid the `shared` scope.

### Examples

```text
fix(nameplates): restore healthbar appearance when a rule stops matching
feat(questtracker): add quest item visibility controls
fix(shared): synchronize profile sections across addons
refactor(shared): update both feature integrations
docs(shared): document repository commit conventions
feat(shared)!: change the profile sharing contract
```

## Validation and completion

1. Review the intended changes and choose the type and required scope.
2. Run relevant validation required by `AGENTS.md` and `TESTING.md` for the
   changed code. Inspect test output rather than relying only on exit codes.
3. Run `git diff --check`; report any missing dependencies or unrun checks.
4. When committing is authorized, stage only the intended paths and review
   `git diff --cached` and `git diff --cached --check`. Confirm that the message
   describes the staged changes and uses their required scope.
5. Create the commit only after these checks. Check `git status --short` afterward.
6. Report the commit hash and subject, validation results, remaining changes,
   and whether it was pushed. Never claim validation or a push that did not run.
