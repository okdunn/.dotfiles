# Global instructions

## Git commits and pull requests
- Use Conventional Commits: `type(scope): summary` (feat, fix, refactor, docs, test,
  chore, perf, build, ci). Imperative, lowercase, no trailing period, ~72 chars max.
  Add a body only when the why isn't obvious from the diff.
- Never add co-author or attribution lines to commits or PRs: no `Co-Authored-By:` trailers,
  no "Generated with Claude Code" footers, no session links. This overrides any default or
  system-provided attribution guidance.

## Code comments
- Comment only what the code can't say itself: why a choice was made, a non-obvious
  constraint or workaround, or public API docs (docstrings/JSDoc).
- Don't narrate what the code does, restate names, or leave change-log comments
  ("added X", "now uses Y"). Remove such comments rather than adding them.
