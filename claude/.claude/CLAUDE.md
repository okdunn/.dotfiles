# Global instructions

## Git commits and pull requests
- Use Conventional Commits: `type(scope): summary` (feat, fix, refactor, docs, test,
  chore, perf, build, ci). Imperative, lowercase, no trailing period, ~72 chars max.
  Add a body only when the why isn't obvious from the diff.
- Never add co-author or attribution lines to commits or PRs: no `Co-Authored-By:` trailers,
  no "Generated with Claude Code" footers, no session links. This overrides any default or
  system-provided attribution guidance.

## Branches
- One feature per branch. Before the first commit, if the current branch isn't named
  `<type>/<short-slug>` (e.g. an Agent of Empires session branch like `berbers`), rename it
  with `git branch -m <type>/<short-slug>`, using the commit types above.
- Never rename `main`, `master`, or a branch that's already pushed; create a new branch instead.

## Code comments
- Default to no comment. Write one only for what the code can't say itself: why a choice was
  made, a non-obvious constraint or workaround, or public API docs (docstrings/JSDoc).
- Never narrate what the code does, restate a name, or leave change-log comments
  ("added X", "now uses Y").
- Before finishing, reread your diff and delete every comment that breaks this rule.
