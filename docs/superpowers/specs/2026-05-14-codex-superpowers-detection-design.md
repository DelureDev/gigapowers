# Design: Correct Codex-side superpowers detection

Date: 2026-05-14
Status: Approved

## Problem

The gigapowers plugin detects whether superpowers is available inside Codex by
checking for a `brainstorming` directory under `~/.codex/skills/`. This is wrong
in two ways against codex-cli 0.130.0:

1. **Wrong path.** Codex keeps *plugin*-provided skills in the plugin cache
   (`~/.codex/plugins/cache/<marketplace>/<plugin>/<hash>/skills/`), not in
   `~/.codex/skills/`. That latter directory only holds Codex's built-in skills.
   So the check is a false negative even on a correct, working install.
2. **Ignores enable state.** A plugin can be installed but disabled
   (`~/.codex/config.toml` → `[plugins."superpowers@<marketplace>"]` with
   `enabled = false`). The current check has no notion of this — and a fresh
   `/plugins` TUI install was observed landing in exactly this disabled state.

The bad check is duplicated across three shipped files, which is how a single
mistake shipped in three places at once:

- `references/codex-install.md` — the "Check if already installed" section.
- `commands/init.md` — step 2 of `/gigapowers:init`.
- `commands/status.md` — step 2 of `/gigapowers:status`.

The SessionStart hook (`hooks/session-start.ps1`) does **not** use this check.

## Goal

Replace the check with one that reflects how Codex 0.130.0 actually stores and
gates plugins, and remove the triplication that caused the bug to spread.

## Approach

Centralize a single detection recipe in `references/codex-install.md` (the
canonical Codex-side reference, already linked from `init.md`). `init.md` and
`status.md` reference that recipe instead of restating their own check. No new
scripts — there are only two markdown consumers, so a shared script would be
premature (YAGNI).

## The detection recipe

The recipe resolves to one of three states:

| State | Condition |
|-------|-----------|
| **ready** | A directory matching `~/.codex/plugins/cache/*/superpowers/*/skills/brainstorming` exists, **and** `~/.codex/config.toml` does not set `enabled = false` for the superpowers plugin table. |
| **installed-but-disabled** | That cache directory exists, **but** `config.toml` has a `[plugins."superpowers@<marketplace>"]` table with `enabled = false`. |
| **not-installed** | No matching cache directory exists. |

Detail:

- **Installed?** Glob `~/.codex/plugins/cache/*/superpowers/*/skills/brainstorming`.
  The marketplace segment (normally `openai-curated`) and the content-hash
  segment are both wildcards; this also covers superpowers added via a
  user-supplied Git marketplace.
- **Enabled?** Read `~/.codex/config.toml`. Find a plugins table whose key
  starts with `superpowers@`. An absent entry or `enabled = true` counts as
  enabled; an explicit `enabled = false` counts as disabled.
- The `~/.codex/skills/` path is dropped entirely.

## File changes

### `references/codex-install.md`

- Rewrite the "Check if already installed" section with the three-state recipe
  above, including a Windows PowerShell snippet (consistent with the rest of the
  doc) scoped to the superpowers plugin table.
- Fix the follow-up line that tells the reader to "re-run the check above to
  confirm `~/.codex/skills/brainstorming` exists" — point it at the corrected
  check.
- In "Install (one-time, interactive)", add an explicit step: after installing,
  ensure the plugin is **enabled** (the `/plugins` TUI may leave it
  `enabled = false`), then restart Codex.

### `commands/init.md` — step 2

Replace the step body with:

> Detect Codex-side superpowers using the recipe in
> `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md`.
> - **ready** → report OK.
> - **installed-but-disabled** → set `enabled = true` for the superpowers plugin
>   table in `~/.codex/config.toml`, tell the user to restart Codex for it to
>   take effect, report as fixed.
> - **not-installed** → relay the install steps from that same file, ask the
>   user to run them once, then continue — do not block the remaining steps.

Add `Edit` to the command's `allowed-tools` frontmatter: the auto-enable is a
targeted one-line config edit and `Edit` is not currently permitted (the list is
`Bash, Read, Write, Skill, AskUserQuestion`).

### `commands/status.md` — step 2

Replace the step body with:

> Detect using the recipe in `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md`;
> report one of **ready**, **installed but disabled** (with the note "run
> /gigapowers:init to enable"), or **not installed**.

`status.md` stays strictly read-only — it reports state, never edits. No
`allowed-tools` change: `Bash` covers the directory glob and `Read` covers
reading `config.toml`.

## Out of scope

- `docs/superpowers/plans/*` and `docs/superpowers/specs/*` — historical
  planning records of the original (flawed) design, not shipped behavior.
- `hooks/session-start.ps1` — does not use this check.
- No new detection script (Approach C considered and rejected as premature).

## Verification

These are markdown instruction files, so there is no automated test. Verify
manually by running the corrected recipe against the live system:

- The plugin cache directory exists, and `~/.codex/config.toml` was set to
  `enabled = true` during diagnosis → the recipe must resolve to **ready**.
- The **installed-but-disabled** branch is verified by reasoning through it;
  flipping the real config back to `enabled = false` would disturb the user's
  working setup, so it is not exercised live.
