# `/implement` via Brainstorming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/implement <ISSUE-ID>` fetch a Linear ticket and hand it to `superpowers:brainstorming`. Track the skill in the dotfiles repo.

**Architecture:** The skill becomes a launcher. It fetches the ticket, builds a brief, and invokes brainstorming with that brief as args. It lives in the `claude` stow package and is linked file by file (`--no-folding` is already set), so untracked skills in `~/.claude/skills` aren't affected.

**Tech Stack:** Claude Code skill (Markdown and YAML frontmatter), the Linear MCP plugin, GNU stow, and bash checks.

**Spec:** `docs/superpowers/specs/2026-11-19-implement-via-brainstorming-design.md`

## Global Constraints

- Linear tools: `mcp__plugin_linear_linear__get_issue`, `mcp__plugin_linear_linear__list_comments` and `mcp__plugin_linear_linear__extract_images`.
- Branch convention: `<type>/<id-lowercase>-<2–5-word-slug>`. `<type>` is one of `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `build`, `ci`.
- Every commit gets a `Refs: <ISSUE-ID>` trailer.
- Nothing from the old skill stays: no proposal template, no own approval gate, no `git checkout main`, no branch, commit or wrap-up phases, no `pnpm`, no port 3000.
- No writes to Linear.
- Global CLAUDE.md comment rules apply. Commits use Conventional Commits with no attribution.

## Review Focus

- **No issue ID given:** the skill asks for one and does nothing else.
- **ID that doesn't exist in Linear:** the skill says so and stops, without invoking brainstorming.
- **Ticket with an empty description:** brainstorming is still invoked. The brief marks the description as empty, so brainstorming asks rather than guesses.
- **Natural-language trigger** ("can you work on SMU-140?"): the skill still triggers and extracts the ID.
- **Install over an existing real `~/.claude/skills/implement/SKILL.md`:** the old file gets backed up, and the other skills in `~/.claude/skills` are left untouched.

---

### Task 1: Rewrite the skill as a brainstorming launcher, tracked in the repo

**Files:**
- Create: `claude/.claude/skills/implement/SKILL.md`
- Create: `claude/.claude/skills/implement/evals/evals.json`

**Interfaces:**
- Produces: the skill name `implement`, invoked as `/implement <ISSUE-ID>`.

- [ ] **Step 1: Write the evals first** (in `evals.json`, keeping `skill_name: "implement"` and the 3 existing prompts: `/implement SMU-159`, `/implement SMU-146`, and the natural-language SMU-140 prompt). Add id 4: `/implement` with no ID. Add id 5: `/implement SMU-99999` (doesn't exist). The expectations for ids 1–3:
  - "A Linear MCP tool is called to fetch <ID> before any codebase work"
  - "Comments for <ID> are fetched with list_comments"
  - "superpowers:brainstorming is invoked via the Skill tool with args containing the ticket title and description"
  - "The brainstorming args include the branch convention `<type>/<id>-<slug>` and the `Refs: <ID>` trailer"
  - "No git branch is created and no files are modified during this run"
  - "No 'Implementation Proposal' template is produced"

  Id 4 expects that the skill asks for an issue ID and makes no tool calls. Id 5 expects a not-found message, with brainstorming not invoked.

- [ ] **Step 2: Run the old skill against eval 1 to confirm it fails the new expectations**

  Run: `claude -p "/implement SMU-159" --output-format stream-json --verbose > /tmp/claude-0/-workspace--dotfiles-worktrees-celts/8b3163a7-7dce-4498-a7dc-28538a9b7336/scratchpad/old.jsonl`, from a scratch directory outside this repo.
  Expected: no `Skill` tool_use with `superpowers:brainstorming` (FAIL). If the Linear call errors on `mcp__linear-server__get_issue`, record that as well.

- [ ] **Step 3: Write `SKILL.md`**
  - **Frontmatter:** `name: implement`. Keep the current description's trigger phrases. Replace "write a proposal … create a semantic git branch … conventional commits" with: "fetches the Linear issue and starts superpowers brainstorming with it, which leads to a design, a plan and the implementation".
  - **Body sections:** Usage (`/implement ENG-123`, and ask if the ID is missing), Fetch (the three tools; stop if the issue isn't found), Hand off (invoke `superpowers:brainstorming` with the brief below, then follow that skill; this skill's work is done), and Rules (don't branch, edit or propose before brainstorming runs; don't write to Linear).
  - **Brief template (exact layout):**

    ```
    Linear ticket <ID>: <title>
    <url>
    Labels: … | Priority: … | Parent: … | Related: …

    ## Description
    <description, or "(empty)">

    ## Comments
    <author, date: body — oldest first, or "(none)">

    ## Conventions for this work
    - Branch: <type>/<id-lowercase>-<2–5 word slug>, type from feat|fix|refactor|docs|test|chore|perf|build|ci (rename the session branch to this in an Agent of Empires session)
    - Every commit ends with the trailer `Refs: <ID>`
    ```

- [ ] **Step 4: Run evals 1, 4 and 5 against the new skill**

  Copy `~/.claude/skills/implement/SKILL.md` to the scratchpad. Then copy the repo's `SKILL.md` over it. Run each prompt the same way as in step 2. Afterwards, restore the original file, so that Task 2's install meets a real file the way other machines will.
  Expected: eval 1 shows `get_issue` → `list_comments` → a `Skill` call with `superpowers:brainstorming`, whose args contain the title and `Refs: SMU-159`. There is no `git checkout`, and `git status` is clean. Eval 4 asks for an ID. Eval 5 reports not found, with no Skill call.

- [ ] **Step 5: Commit**

  ```bash
  git add claude/.claude/skills/implement
  git commit -m "feat(claude): make implement skill hand linear tickets to brainstorming"
  ```

### Task 2: Install and check the skill link

**Files:**
- Modify: `install/checks.sh` (`run_checks`, after the `~/.claude/CLAUDE.md linked` line)
- Modify: `tests/cleanroom.sh` (pre-seed and assert)
- Modify: `README.md:72` (the Claude Code paragraph)

**Interfaces:**
- Consumes: `claude/.claude/skills/implement/SKILL.md` from Task 1.

- [ ] **Step 1: Add the check.** `_check "implement skill linked" test -L "$HOME/.claude/skills/implement/SKILL.md"`

- [ ] **Step 2: Run `dot check` and confirm the new line fails.** It should fail because `~/.claude/skills/implement/SKILL.md` is still a real file.

- [ ] **Step 3: Extend `tests/cleanroom.sh`.** Before `install.sh`, seed `mkdir -p ~/.claude/skills/other && echo x > ~/.claude/skills/other/SKILL.md` and an old `~/.claude/skills/implement/SKILL.md`. After the install, assert all three of these:
  - `~/.claude/skills/implement/SKILL.md` is a symlink into `~/.dotfiles`.
  - `~/.claude/skills` is a real directory.
  - `~/.claude/skills/other/SKILL.md` still exists.

  On failure, print `FAIL: …` and exit 1, matching the existing style.

- [ ] **Step 4: Update the README** with one sentence: the tracked skills under `claude/.claude/skills/` are linked per file, and other skills in `~/.claude/skills` stay local.

- [ ] **Step 5: Install on this machine and verify.**
  - Run `bash install.sh --stow-only`.
  - Expected: the log shows `Backing up …/.claude/skills/implement/SKILL.md`, and `run_checks` shows `implement skill linked` ✓.
  - `tests/check.sh` passes.
  - `tests/check.sh --cleanroom` passes if Docker is available. If it isn't, say it was skipped.

- [ ] **Step 6: Commit**

  ```bash
  git add install/checks.sh tests/cleanroom.sh README.md
  git commit -m "test(install): check implement skill is stowed per file"
  ```
