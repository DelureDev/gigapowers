---
description: Force an immediate Codex-side defensive refresh and reset the throttle timestamp
allowed-tools: Bash, Read, Write
---

Force the Codex-side refresh now, bypassing the 24h throttle.

Note: superpowers ships in Codex's built-in `openai-curated` marketplace, which
Codex keeps current itself. `codex plugin marketplace upgrade` refreshes any
*user-added* Git marketplaces — for the built-in one it is a harmless no-op.
This command is the manual escape hatch for that defensive refresh plus a
throttle reset.

1. If `codex` is not installed, or `codex login status` exits non-zero, report
   that clearly and stop — do not write the timestamp. (`codex login status`
   catches stale or invalid credentials that a bare `auth.json` file does not.)
2. Run `codex plugin marketplace upgrade` and capture the output.
3. Write the current timestamp (ISO 8601, e.g. the output of
   `(Get-Date).ToString('o')`) to `~/.gigapowers/last-sync`, creating the
   `~/.gigapowers/` directory if needed.
4. Report what `upgrade` did and the new timestamp.
