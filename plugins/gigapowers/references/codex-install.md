# Installing superpowers into Codex

Resolved 2026-05-14 against `codex-cli 0.130.0` on Windows.

## TL;DR

- **First install is interactive.** codex-cli 0.130.0 has no `codex plugin
  install` command — plugins are installed through the `/plugins` TUI.
- **Updates are automatic.** superpowers ships in the built-in `openai-curated`
  marketplace, which Codex keeps current on its own.

## Check if already installed

Superpowers is live in Codex when `~/.codex/skills/` contains a `brainstorming`
directory:

```powershell
Test-Path "$HOME\.codex\skills\brainstorming"
```

`True` → superpowers is installed, nothing to do. `False` → run the one-time
install below.

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
5. Quit and reopen Codex.

Then re-run the check above to confirm `~/.codex/skills/brainstorming` exists.

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
