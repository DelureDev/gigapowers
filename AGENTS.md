# Project: gigapowers

> Single source of truth for both Claude and Codex. CLAUDE.md imports this file;
> do not duplicate content between them.

## Stack
- Language + version: PowerShell 5.1+ (SessionStart hook + plain-PowerShell unit
  tests), Node.js ESM (hook launcher, scripts), Markdown (commands, skills,
  references, templates), JSON (plugin/marketplace manifests, hook config).
- Frameworks: a Claude Code plugin published via the `gigapowers` marketplace;
  sits on top of the `superpowers` and `codex@openai-codex` plugins.
- Tooling (lint, format, type check, test): no linter or formatter; tests are
  plain-PowerShell unit tests (no Pester dependency).

## Conventions
- Test command: `powershell -NoProfile -File tests/throttle.tests.ps1`
  (use `pwsh` instead of `powershell` on PowerShell 7 / macOS / Linux).
- Lint / format command: none.
- Commit style: Conventional Commits.
- Branch naming: <type>/<short-description>.
- Version bumps: run `node scripts/bump-version.mjs <major.minor.patch>` — never
  hand-edit the version in plugin.json / marketplace.json.

## Domain
- What this project does: a Claude Code plugin that wires Codex CLI in as a
  mandatory peer collaborator. It ships `/gigapowers:init` (per-project
  bootstrap of both superpowers stacks + Codex stop-gate), `/gigapowers:status`
  (health report), `/gigapowers:sync` (manual Codex-side refresh), a throttled
  SessionStart hook (defensive Codex-side refresh), and the
  `orchestrating-codex` skill (decides when/how Claude brings Codex in).
- Key concepts / glossary:
  - **Stop-gate**: the codex plugin's Stop hook → adversarial review before
    Claude ends an edit-turn. Optional; `/gigapowers:init` enables and verifies it.
  - **Defensive refresh**: a throttled (24h) `codex plugin marketplace upgrade`
    run from the SessionStart hook; a harmless no-op for the built-in marketplace.
  - **Throttle**: the `~/.gigapowers/last-sync` timestamp plus an atomic lock
    that bounds the refresh to once per 24h and serializes concurrent sessions.

## Don't
- No secrets or PII in logs or commits.
- No new SaaS or network dependencies without approval.
- No `--dangerously-skip-permissions`.
