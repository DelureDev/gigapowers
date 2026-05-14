# Gigapowers

A Claude Code plugin that makes Claude and Codex build software as **peers**.
Claude orchestrates; Codex is structurally always in the loop.

Gigapowers sits on top of [superpowers](https://github.com/obra/superpowers)
(installed in both Claude Code and Codex) and the `codex@openai-codex` plugin.
It reimplements neither — it is the thin layer that bootstraps both stacks,
keeps the Codex side current, and carries the orchestration brain.

## What you get

- **`/gigapowers:init`** — bootstraps a project: verifies both superpowers
  stacks, scaffolds `AGENTS.md` / `CLAUDE.md` / `.codex/config.toml`, ensures
  git and the Codex stop-gate.
- **`/gigapowers:status`** — health check of both stacks, Codex auth, last
  auto-update.
- **`/gigapowers:sync`** — force a Codex-side defensive refresh now.
- **`orchestrating-codex` skill** — the brain: when and how Claude brings Codex
  in across design, planning, implementation, review, and debugging.
- **SessionStart hook** — throttled (24h) defensive Codex-side refresh +
  readiness check. The Claude side is handled by Claude Code itself.

## Install

```
claude plugin marketplace add DelureDev/gigapowers
claude plugin install gigapowers@gigapowers
```

Then in any project: `/gigapowers:init`.

## Requirements

- Claude Code with the `superpowers` and `codex@openai-codex` plugins.
- Codex CLI (`codex`) installed and authenticated.
- Windows (the SessionStart hook is PowerShell; a bash fallback is planned).

## Codex-side superpowers

superpowers ships in Codex's built-in `openai-curated` marketplace. codex-cli
0.130.0 has no non-interactive plugin install, so the first install is a
one-time interactive step — see
[`references/codex-install.md`](./references/codex-install.md). Updates are
handled by Codex's own marketplace refresh.

## License

MIT — see [LICENSE](../../LICENSE).
