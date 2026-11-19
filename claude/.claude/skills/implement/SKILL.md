---
name: implement
description: "Implement a Linear issue end-to-end: fetch the ticket and its comments, then start superpowers brainstorming with it, which leads to a design, a plan and the implementation. Use this skill whenever the user says \"implement [issue-id]\", \"/implement ENG-123\", \"work on ticket X\", \"pick up LINEAR-456\", \"implement this issue\", or any variant of starting work on a Linear ticket. Always invoke this skill when a Linear issue ID is mentioned in the context of doing implementation work."
---

# Implement

Starts superpowers work from a Linear ticket. This skill fetches the ticket and hands it to
`superpowers:brainstorming` as the brief. Brainstorming, and the skills it hands off to, own
everything after that: approaches, the design doc, the plan, branching, commits and finishing.

## Usage

```
/implement ENG-123
```

Take the issue ID from the arguments, or from the user's message when they ask in their own
words ("can you work on ENG-123?"). If there is no ID, ask for one and do nothing else.

## 1. Fetch the ticket

1. `mcp__plugin_linear_linear__get_issue` with the ID. Note the title, URL, status, labels,
   priority, parent issue and related issues.
2. `mcp__plugin_linear_linear__list_comments` with the ID. `get_issue` does not include the
   discussion, and comments often change what the ticket asks for.
3. If the description or comments embed images, view them with
   `mcp__plugin_linear_linear__extract_images`. Describe what they show in the brief, because
   brainstorming can't see the images.

If the issue isn't found, tell the user and stop. Don't invoke brainstorming.

## 2. Hand off to brainstorming

Invoke `superpowers:brainstorming` with the Skill tool. Pass this brief as `args`, filled in from
the ticket:

```
Linear ticket <ID>: <title>
<url>
Status: … | Labels: … | Priority: … | Parent: … | Related: …

## Description
<description, or "(empty)">

## Comments
<author, date: body — oldest first, or "(none)">

## Notes
<anything that could change whether or how to start: the ticket is done, canceled or already
has a PR in review, or the working directory isn't the repo the ticket is about — or "(none)">

## Conventions for this work
- Branch: <type>/<id-lowercase>-<2–5 word slug>, type from feat|fix|refactor|docs|test|chore|perf|build|ci (rename the session branch to this in an Agent of Empires session)
- Every commit ends with the trailer `Refs: <ID>`
- Create or rename to this branch before the first commit, including the design doc commit
- Record these conventions as constraints in the design doc, so the plan and every implementer carry them
```

Keep the description and comments as written. Don't summarize them: the wording is the
requester's intent. Where the brief says "(empty)" or "(none)", brainstorming asks rather than
guesses.

Then follow brainstorming. This skill's work is done.

## Rules

- Don't create a branch, edit files or write your own proposal before brainstorming runs. Its
  approval gate is the only one.
- A found ticket always goes to brainstorming. If it looks done, already in review, or out of
  place in this directory, put that under Notes instead of stopping: brainstorming raises it
  with the user, who decides in the same conversation.
- Don't write to Linear (status, comments, assignee) unless the user asks.
