# Installing superpowers into Codex

Resolved 2026-05-14 against `codex-cli 0.130.0` on Windows.

## TL;DR

- **First install is interactive.** codex-cli 0.130.0 has no `codex plugin
  install` command — plugins are installed through the `/plugins` TUI.
- **Updates are automatic.** superpowers ships in the built-in `openai-curated`
  marketplace, which Codex keeps current on its own.

## Check if already installed

Codex 0.130.0 keeps *plugin*-provided skills in the plugin cache, not in
`~/.codex/skills/` (that directory does not hold plugin-provided skills). A plugin
can also be installed but disabled. Detection therefore has three states:

| State | Meaning |
|-------|---------|
| **ready** | Installed and enabled — nothing to do. |
| **installed-but-disabled** | Installed, but turned off in `config.toml`. Enable it (below), then restart Codex. |
| **not-installed** | Not present — run the one-time install below. |

**Installed?** A directory matching this glob exists:

```powershell
Get-ChildItem "$HOME\.codex\plugins\cache\*\superpowers\*\skills\brainstorming" -Directory -ErrorAction SilentlyContinue
```

The marketplace segment (normally `openai-curated`) and an install-specific segment
are wildcards — this also covers superpowers added via a user Git marketplace.

**Enabled?** Read `~/.codex/config.toml`. Find a table whose key starts with
`[plugins."superpowers@`. An absent entry or `enabled = true` means enabled; an
explicit `enabled = false` means disabled:

```powershell
Select-String -Path "$HOME\.codex\config.toml" -Pattern '^\s*\[plugins\."superpowers@' -Context 0,10 -ErrorAction SilentlyContinue
```

No output from that command means there is no `superpowers@` plugin table —
treat that as enabled (the default). If the block shows `enabled = false`, set
it to `enabled = true` and restart Codex. Combine the two checks: installed +
not-disabled → **ready**; installed + disabled → **installed-but-disabled**; not
installed → **not-installed**.

## Install (one-time, interactive)

There is no scriptable install path in codex-cli 0.130.0. `codex plugin` only
exposes `marketplace add|upgrade|remove`, and the marketplace that carries
superpowers (`openai-curated`) is reserved/built-in — `codex plugin marketplace
add openai/plugins` fails with *"marketplace 'openai-curated' is reserved"*.

Tell the user to run these steps once:

1. Open Codex: `codex`
2. In the TUI, open the plugin browser: `/plugins`
3. Search for: `superpowers`
4. Select **Install Plugin**.
5. Ensure the plugin is **enabled** — the TUI may leave a freshly installed
   plugin `enabled = false`. Toggle it on, or set `enabled = true` under
   `[plugins."superpowers@openai-curated"]` in `~/.codex/config.toml`.
6. Quit and reopen Codex.

Then re-run the detection above to confirm the state is **ready**.

## Update

superpowers is part of the built-in `openai-curated` marketplace. Codex refreshes
that marketplace itself (the clone under `~/.codex/.tmp/plugins`, tracked by
`~/.codex/.tmp/plugins.sha`) — no action needed to stay current.

`codex plugin marketplace upgrade` only refreshes **user-added Git
marketplaces**; for the built-in `openai-curated` it is a harmless no-op
(`No configured Git marketplaces to upgrade.`). The gigapowers SessionStart hook
still runs it defensively — it costs nothing and covers the case where the user
later adds superpowers as a standalone Git marketplace.

## Why the hook still earns its place

Even though updates are largely Codex's job, the SessionStart hook:

- runs `codex plugin marketplace upgrade` defensively (cheap, covers user-added
  Git marketplaces),
- is the natural home for the readiness check (is `codex` on PATH? authed?),
- keeps a throttle timestamp so `/gigapowers:status` can report "last checked".
