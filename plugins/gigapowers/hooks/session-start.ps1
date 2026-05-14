# Gigapowers SessionStart hook.
# Throttled (24h) defensive Codex-side refresh + cheap readiness check.
# Windows-first. Never blocks the session; never exits non-zero.
#
# Note: superpowers ships in Codex's built-in `openai-curated` marketplace,
# which Codex keeps current itself. `codex plugin marketplace upgrade` here is
# defensive -- it refreshes any *user-added* Git marketplaces and is a harmless
# no-op otherwise. See references/codex-install.md.

$ErrorActionPreference = 'SilentlyContinue'

. "$PSScriptRoot/lib/throttle.ps1"

$stateDir = Join-Path $HOME '.gigapowers'
$stamp    = Join-Path $stateDir 'last-sync'

# Readiness check: if Codex is not on PATH there is nothing to refresh.
# Stay silent -- a missing Codex is the user's choice, not a hook error.
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) { exit 0 }

# Throttled refresh. The timestamp is written on *dispatch*, not completion:
# if the upgrade fails (e.g. offline) the next attempt is the following stale
# window. This is the documented v1 tradeoff (spec section 8).
if (Test-SyncStale -TimestampFile $stamp) {
    # Detach the slow upgrade so session start is never blocked.
    Start-Process -WindowStyle Hidden -FilePath $codex.Source `
        -ArgumentList 'plugin','marketplace','upgrade' -ErrorAction SilentlyContinue
    Write-SyncTimestamp -TimestampFile $stamp
}

exit 0
