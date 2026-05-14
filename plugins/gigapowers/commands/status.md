---
description: Show gigapowers health — both superpowers stacks, Codex CLI and auth, last auto-update, stop-gate state
allowed-tools: Bash, Read
---

Report gigapowers health. This command is read-only — change nothing.

1. **Claude-side superpowers** — read `~/.claude/plugins/installed_plugins.json`;
   report the `superpowers@claude-plugins-official` version, or "not installed".
2. **Codex-side superpowers** — detect using the recipe in
   `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md` ("Check if already
   installed"); report one of **ready**, **installed but disabled** (add the
   note "run /gigapowers:init to enable"), or **not installed**. This command is
   read-only — report state, do not edit `config.toml`.
3. **Codex CLI** — run `codex --version`; report the version, or "not installed".
4. **Codex auth** — run `codex login status`; report **authenticated** when it
   exits 0 (e.g. prints "Logged in using ChatGPT"), otherwise **not
   authenticated**. Do not infer auth from `~/.codex/auth.json` existing — that
   file can be present but hold stale or invalid credentials.
5. **Last auto-update** — read `~/.gigapowers/last-sync`; report the timestamp
   and how long ago that was, or "never".
6. **Stop-gate** — report whether the codex plugin's stop-review gate is
   enabled (use `codex:setup` state if available, otherwise note "run
   /gigapowers:init or codex:setup to confirm").

Print a compact status table, one row per item.
