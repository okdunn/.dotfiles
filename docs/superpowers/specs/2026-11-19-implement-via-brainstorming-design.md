# `/implement` hands Linear tickets to superpowers brainstorming

## Intent

`/implement ENG-123` should start real design work from a Linear ticket rather than run its own
one-off proposal flow. The skill fetches the ticket and passes it into
`superpowers:brainstorming` as the starting brief. From there the superpowers path (approaches,
design doc, plan, execution, finishing) owns the work.

## Goals

- Fetch the ticket (title, description, labels, priority, parent and related issues, and comments)
  and pass it as the brainstorming brief.
- Carry the ticket conventions forward so the design and plan pick them up: put the issue ID in the
  branch name and add a `Refs: ENG-123` trailer to every commit.
- Track the skill in this dotfiles repo so changes to it have a history.

## Non-goals

- Re-implementing branching, planning, committing or wrap-up inside `/implement`.
- Writing back to Linear (status changes, comments).

## Anti-goals

- Two frameworks both owning branching and commits.
- `/implement` skipping or shortcutting brainstorming's approval gate.

## Approaches

- **A. Thin launcher (picked):** fetch the ticket and hand off to brainstorming. Superpowers owns
  everything after that, and the only ticket-specific additions are the branch name and the
  `Refs:` trailer. Picked because it uses one workflow end to end.
- **B. Wrapper:** keep `/implement`'s branch, commit and wrap-up phases and use superpowers only
  for the design. Rejected because two frameworks would both try to own branching and commits.

## Design

`claude/.claude/skills/implement/SKILL.md` gets stowed to `~/.claude/skills/implement/SKILL.md`:

1. Take the issue ID from the arguments. If there isn't one, ask for it.
2. Fetch the issue with `mcp__plugin_linear_linear__get_issue` and its comments with
   `list_comments`. If the description or comments contain images, view them with
   `extract_images`. If the issue isn't found, say so and stop.
3. Invoke `superpowers:brainstorming` through the Skill tool. The args are a brief containing the
   issue ID, URL, title, labels, priority, parent and related issues, the description, the
   comments, and these conventions:
   - Branch: `<type>/<id-lowercase>-<2–5-word-slug>`, where `<type>` comes from the commit types
     in the global CLAUDE.md (`feat`, `fix`, `refactor`, `docs`, `chore`, …). In an Agent of
     Empires session, the session branch gets renamed to this name.
   - Every commit has a `Refs: <ISSUE-ID>` trailer.
4. Follow brainstorming from that point. `/implement` has nothing more to do.

The frontmatter description keeps the current trigger phrases. It adds that the skill starts
superpowers brainstorming and drops the "proposal" wording.

What gets removed: the proposal template, the separate approval gate, `git checkout main`, the
branch, commit and wrap-up phases, `pnpm typecheck`/`pnpm lint`, and the port 3000 check.

Evals (`claude/.claude/skills/implement/evals/evals.json`) get rewritten to check these things:
Linear is fetched before any codebase work, brainstorming is invoked with the ticket content, and
no branch is created and no file is changed before a design is approved.

## Constraints

- The current skill is a real directory at `~/.claude/skills/implement`. The installer's
  `backup_conflicts` backs up the conflicting `SKILL.md` before stowing, so no extra migration code
  is needed. `~/.claude/skills/implement-workspace` (old eval runs) stays untracked.
- The `claude` stow package currently contains only `.claude/CLAUDE.md`. Adding `skills/` must not
  fold `~/.claude/skills` into one symlink, because other untracked skills live there.

## Left to the builder

- Exact wording of the brief and the skill text.
- Whether the stow-folding concern needs `--no-folding` or a check in `install/checks.sh`.
