# This repo is public

Everything committed here is published on GitHub, including the full history, so it must not
contain sensitive or identifying details. This covers code, config, tests and fixtures, docs
(including `docs/superpowers/` specs and plans), commit messages, branch names and PR text.

Never commit:

- Secrets of any kind: tokens, API keys, passwords, private keys, session cookies.
- Names of other repos, projects, companies, clients or products the owner works on, or details of
  how they're built (folder layouts, service counts, internal tool names).
- Ticket or issue IDs and titles (Linear, Jira, GitHub issues of other repos).
- Domains, hostnames, IP addresses (including tailnet ones), DNS records, URLs of private
  services.
- Personal details: email addresses, usernames, absolute home paths (`/home/<user>`; use `~` or
  `$HOME`), hardware specs, the names of containers or volumes on this machine.

When a doc or test needs a concrete example, describe it generically ("a Go monorepo with
`go.work` and no root module") or use placeholders (`app`, `backend`, `example.com`,
`FOO-123`). Anything specific to one machine or project goes in the untracked files the README
lists (`~/.zshrc.local`, `~/.zshrc.d/<name>.zsh`, `~/.gitconfig.local`, aoe profile configs).

Before every commit, read the staged diff and the commit message for anything on this list. If
something slipped into an earlier commit, say so instead of committing a fix on top: deleting it in
a new commit leaves it in the history, so unpushed history has to be rewritten.
