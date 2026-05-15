# Codex Review Findings — Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every finding from the merged Claude + Codex adversarial review of the gigapowers plugin — replace asserted state with verified state, make the SessionStart hook cross-platform, close the throttle race, and clean up repo hygiene.

**Architecture:** Most findings are doc/prompt corrections to the `commands/*.md`, `references/*.md`, and `skills/*` Markdown. Two are code: a Node launcher shim that makes the PowerShell hook cross-platform, and an atomic lock in the throttle library. One is repo hygiene: relocate the misplaced dogfood `AGENTS.md`/`CLAUDE.md`/`.codex/` from `plugins/gigapowers/` to the repo root, filled out. Node is already a transitive dependency (the `codex@openai-codex` plugin ships `codex-companion.mjs`), so Node is the right tool for cross-platform launchers and the version-bump script.

**Tech Stack:** Markdown (commands, skills, references, templates), PowerShell 5.1+ (hooks + plain-PowerShell unit tests, no Pester), Node.js ESM (launchers, scripts), JSON (plugin/marketplace manifests, hook config).

**Branch:** All work happens on `fix/codex-review-findings` (created off `main` before Task 1).

**Decisions already made (do not re-litigate):**
- H2 auth check uses `codex login status` (exit 0 + "Logged in using ChatGPT") — free, no quota burn.
- Codex-2 / H1: `/gigapowers:init` **forces the Stop-gate on AND verifies it took**; the `orchestrating-codex` skill is reworded so pre-completion review is Claude's responsibility regardless of gate state.
- Codex-6 (global `SilentlyContinue`): **deliberately not changed** — it is the hook's documented "never block/fail the session" contract. The fix is a rationale comment so future readers don't read it as an oversight. This is a verified disagreement with Codex's "Medium bug" rating.
- Codex-4: the dispatch-time timestamp is a documented intentional tradeoff; only the *label* "last auto-update" overclaims — relabel, don't change code behavior.
- L2: `references/codex-install.md:3` ("Resolved 2026-05-14 against codex-cli 0.130.0") is acceptable dated provenance and is left as-is; the L2 fix is only `templates/codex-config.toml`.

---

### Task 1: H2 — replace file-existence auth check with a live check

**Files:**
- Modify: `plugins/gigapowers/commands/status.md:16-17`
- Modify: `plugins/gigapowers/commands/sync.md:14-15`

- [ ] **Step 1: Fix the auth check in `status.md`**

Replace item 4 (lines 16-17):

```markdown
4. **Codex auth** — check whether `~/.codex/auth.json` exists; report
   authenticated or not.
```

with:

```markdown
4. **Codex auth** — run `codex login status`; report **authenticated** when it
   exits 0 (e.g. prints "Logged in using ChatGPT"), otherwise **not
   authenticated**. Do not infer auth from `~/.codex/auth.json` existing — that
   file can be present but hold stale or invalid credentials.
```

- [ ] **Step 2: Fix the auth gate in `sync.md`**

Replace step 1 (lines 14-15):

```markdown
1. If `codex` is not installed or `~/.codex/auth.json` is missing, report that
   clearly and stop — do not write the timestamp.
```

with:

```markdown
1. If `codex` is not installed, or `codex login status` exits non-zero, report
   that clearly and stop — do not write the timestamp. (`codex login status`
   catches stale or invalid credentials that a bare `auth.json` file does not.)
```

- [ ] **Step 3: Verify**

Read both files back; confirm neither command-flow gates on `auth.json` existence and both use `codex login status`. Confirm `codex login status` works locally:

Run: `codex login status; echo "exit=$?"`
Expected: `Logged in using ChatGPT` then `exit=0`

- [ ] **Step 4: Commit**

```bash
git add plugins/gigapowers/commands/status.md plugins/gigapowers/commands/sync.md
git commit -m "fix: check Codex auth with codex login status, not auth.json existence"
```

---

### Task 2: H1 + Codex-2 — make the Stop-gate verified, not assumed

**Files:**
- Modify: `plugins/gigapowers/skills/orchestrating-codex/SKILL.md:13-25`
- Modify: `plugins/gigapowers/commands/init.md:51-53`

- [ ] **Step 1: Rework the Stop-gate guidance in `SKILL.md`**

Replace the "When to bring Codex in" section (lines 13-25) with:

```markdown
## When to bring Codex in

| Stage | What Codex does | How |
|-------|-----------------|-----|
| Design / brainstorm | Stress-tests an approach when 2+ are viable | `codex exec` consult |
| Planning | Reads the plan for gaps and missed edge cases | `codex exec` consult |
| Implementation | Takes parallel batch work; second opinion on a tricky unit | `codex:codex-rescue` agent |
| Before "done" | Adversarial review of the diff | Stop-gate if enabled, else `codex exec` yourself |
| Stuck (2+ failed debug rounds) | Fresh-context diagnosis | `codex:codex-rescue` agent |

You decide the judgment-call rows. **Pre-completion adversarial review is your
responsibility either way.** The codex plugin's Stop-gate automates it *when
enabled* — but the gate is optional and may be off. Before declaring a
non-trivial task done, confirm a Codex adversarial pass actually happened: if
the Stop-gate is on it fired automatically (don't duplicate it); if it's off,
run one yourself with `codex exec`. Never skip the review on the assumption the
gate covered it.
```

- [ ] **Step 2: Make `init.md` step 7 force-and-verify the gate**

Replace step 7 (lines 51-53):

```markdown
## 7. Ensure the Codex stop-gate
Invoke the `codex:setup` skill to confirm Codex is installed and authenticated
and that the stop-time review gate is enabled.
```

with:

```markdown
## 7. Ensure the Codex stop-gate
Invoke the `codex:setup` skill with `--enable-review-gate` to enable the
stop-time review gate, then **verify it actually took** — `codex:setup` reports
the review-gate state; confirm it reads **enabled**. Do not report this step
done on the strength of the invocation alone.
- Review gate verified enabled → report **done**.
- Codex unavailable or not authenticated → report **needs user action** with the
  reason `codex:setup` gave; do not claim the gate is on.
- Invoked but the state still reads disabled → report **needs user action**:
  "stop-gate did not enable — run `/codex:setup --enable-review-gate` and
  confirm Codex is set up."
```

- [ ] **Step 3: Verify**

Read both files back. Confirm `SKILL.md` no longer says the Stop-gate is "automatic — do not duplicate it" as an unconditional claim, and `init.md` step 7 both passes `--enable-review-gate` and has an explicit verification branch.

- [ ] **Step 4: Commit**

```bash
git add plugins/gigapowers/skills/orchestrating-codex/SKILL.md plugins/gigapowers/commands/init.md
git commit -m "fix: verify the Codex Stop-gate instead of assuming it is on"
```

---

### Task 3: M1 — cross-platform SessionStart hook launcher

**Files:**
- Create: `plugins/gigapowers/hooks/session-start.mjs`
- Modify: `plugins/gigapowers/hooks/hooks.json:9-11`

- [ ] **Step 1: Create the Node launcher shim**

Create `plugins/gigapowers/hooks/session-start.mjs`:

```javascript
#!/usr/bin/env node
// Cross-platform launcher for the gigapowers SessionStart hook.
// On Windows it dispatches the PowerShell hook (detached, non-blocking).
// On macOS/Linux it is currently a clean no-op -- the bash port is planned
// (see README "Requirements"). Either way it never blocks or fails the session.
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

try {
  if (process.platform === "win32") {
    const here = dirname(fileURLToPath(import.meta.url));
    const ps1 = join(here, "session-start.ps1");
    const child = spawn(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1],
      { detached: true, stdio: "ignore" }
    );
    child.unref();
  }
} catch {
  // Never block or fail the session over a hook-launch error.
}
process.exit(0);
```

- [ ] **Step 2: Point `hooks.json` at the Node launcher**

In `plugins/gigapowers/hooks/hooks.json`, replace the `command` line (line 10):

```json
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.ps1\"",
```

with:

```json
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.mjs\"",
```

(Leave `"type": "command"` and `"timeout": 15` unchanged — the shim returns immediately because the PowerShell child is detached.)

- [ ] **Step 3: Verify on this (Windows) machine**

Run: `node plugins/gigapowers/hooks/session-start.mjs; echo "exit=$?"`
Expected: `exit=0`, no thrown error, no console output. (The detached PowerShell child runs `session-start.ps1` in the background; it is throttled so it may be a no-op.)

- [ ] **Step 4: Verify the non-Windows path by inspection**

Confirm by reading `session-start.mjs` that when `process.platform !== "win32"` the script does nothing except `process.exit(0)` — i.e. on macOS/Linux it is a clean no-op, not an error. (`node` itself is required transitively by the `codex@openai-codex` plugin, so it is present wherever gigapowers runs.)

- [ ] **Step 5: Commit**

```bash
git add plugins/gigapowers/hooks/session-start.mjs plugins/gigapowers/hooks/hooks.json
git commit -m "fix: launch SessionStart hook via Node shim so it no longer errors on macOS/Linux"
```

---

### Task 4: L3 — close the throttle TOCTOU race with an atomic lock

**Files:**
- Modify: `plugins/gigapowers/hooks/lib/throttle.ps1` (append two functions after line 41)
- Test: `tests/throttle.tests.ps1` (append cases after line 42)
- Modify: `plugins/gigapowers/hooks/session-start.ps1:22-30`

- [ ] **Step 1: Write the failing tests**

In `tests/throttle.tests.ps1`, immediately after line 42 (`Assert-Equal $false (Test-SyncStale ...) 'just-written timestamp not stale'`) and before the closing `}` on line 43, add:

```powershell

    # --- sync lock (Task 4: TOCTOU fix) ---
    $lock = "$tmp/sync.lock"
    Assert-Equal $true  (Test-AcquireSyncLock -LockFile $lock) 'first acquire wins the lock'
    Assert-Equal $false (Test-AcquireSyncLock -LockFile $lock) 'second acquire is refused while lock is held'
    Remove-SyncLock -TimestampFile $lock
    Assert-Equal $false (Test-Path $lock) 'Remove-SyncLock deletes the lock file'
    Assert-Equal $true  (Test-AcquireSyncLock -LockFile $lock) 'acquire succeeds again after release'
    Remove-SyncLock -TimestampFile $lock

    $nestedLock = "$tmp/x/y/sync.lock"
    Assert-Equal $true (Test-AcquireSyncLock -LockFile $nestedLock) 'acquire creates the nested lock dir'
    Remove-SyncLock -TimestampFile $nestedLock

    $staleLock = "$tmp/stale.lock"
    New-Item -ItemType File -Path $staleLock | Out-Null
    (Get-Item $staleLock).LastWriteTime = $now.AddMinutes(-10)
    Assert-Equal $true (Test-AcquireSyncLock -LockFile $staleLock -Now $now) 'abandoned lock (>5m old) is reclaimed'
    Remove-SyncLock -TimestampFile $staleLock
```

Note: `Remove-SyncLock` takes `-TimestampFile` (not `-LockFile`) — see Step 3; the parameter name is shared with the other throttle helpers for consistency, and the value passed is the lock-file path.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `powershell -NoProfile -File tests/throttle.tests.ps1`
Expected: FAIL — `Test-AcquireSyncLock` / `Remove-SyncLock` are not defined (`$ErrorActionPreference = 'Stop'` at the top of the test file makes the unknown command throw, so the run exits non-zero).

- [ ] **Step 3: Implement the lock functions in `throttle.ps1`**

Append to `plugins/gigapowers/hooks/lib/throttle.ps1` (after line 41, the closing `}` of `Write-SyncTimestamp`):

```powershell

function Test-AcquireSyncLock {
    <#
      Atomically claims the sync lock. Creates $LockFile only if it does not
      already exist (FileMode CreateNew is atomic), so two concurrent
      SessionStart events cannot both win. Returns $true when this caller now
      owns the lock, $false when another caller already holds it.

      An abandoned lock (a crashed session that never released it) older than
      $StaleMinutes is reclaimed -- the real lock is only held for the
      milliseconds it takes to dispatch a detached process, so any lock that
      old is dead.
    #>
    param(
        [Parameter(Mandatory)][string]$LockFile,
        [int]$StaleMinutes = 5,
        [datetime]$Now = (Get-Date)
    )
    $dir = Split-Path -Parent $LockFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $LockFile) {
        $age = $Now - (Get-Item -LiteralPath $LockFile).LastWriteTime
        if ($age.TotalMinutes -ge $StaleMinutes) {
            Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
        }
    }
    try {
        $fs = [System.IO.File]::Open($LockFile, [System.IO.FileMode]::CreateNew)
        $fs.Close()
        return $true
    } catch {
        return $false
    }
}

function Remove-SyncLock {
    <#
      Releases the sync lock. Safe to call when the lock is already gone.
      Parameter is named -TimestampFile to match the other throttle helpers;
      pass the lock-file path.
    #>
    param(
        [Parameter(Mandatory)][string]$TimestampFile
    )
    Remove-Item -LiteralPath $TimestampFile -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `powershell -NoProfile -File tests/throttle.tests.ps1`
Expected: PASS — `All throttle tests passed`, exit 0, including the 6 new lock cases.

- [ ] **Step 5: Use the lock in `session-start.ps1`**

In `plugins/gigapowers/hooks/session-start.ps1`, replace the throttle block (lines 22-30):

```powershell
# Throttled refresh. The timestamp is written on *dispatch*, not completion:
# if the upgrade fails (e.g. offline) the next attempt is the following stale
# window. This is the documented v1 tradeoff (spec section 8).
if (Test-SyncStale -TimestampFile $stamp) {
    # Detach the slow upgrade so session start is never blocked.
    Start-Process -WindowStyle Hidden -FilePath $codex.Source `
        -ArgumentList 'plugin','marketplace','upgrade' -ErrorAction SilentlyContinue
    Write-SyncTimestamp -TimestampFile $stamp
}
```

with:

```powershell
# Throttled refresh, guarded by an atomic lock so two concurrent SessionStart
# events cannot both dispatch. The timestamp is written on *dispatch*, not
# completion: if the upgrade fails (e.g. offline) the next attempt is the
# following stale window. This is the documented v1 tradeoff (spec section 8).
$lock = "$stamp.lock"
if (Test-AcquireSyncLock -LockFile $lock) {
    try {
        if (Test-SyncStale -TimestampFile $stamp) {
            # Detach the slow upgrade so session start is never blocked.
            Start-Process -WindowStyle Hidden -FilePath $codex.Source `
                -ArgumentList 'plugin','marketplace','upgrade' -ErrorAction SilentlyContinue
            Write-SyncTimestamp -TimestampFile $stamp
        }
    } finally {
        Remove-SyncLock -TimestampFile $lock
    }
}
```

- [ ] **Step 6: Re-run the tests and smoke-test the hook**

Run: `powershell -NoProfile -File tests/throttle.tests.ps1`
Expected: PASS — `All throttle tests passed`, exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/gigapowers/hooks/session-start.ps1; echo "exit=$?"`
Expected: `exit=0`, no output, and no leftover `~/.gigapowers/last-sync.lock` file (the `finally` block removes it).

- [ ] **Step 7: Commit**

```bash
git add plugins/gigapowers/hooks/lib/throttle.ps1 tests/throttle.tests.ps1 plugins/gigapowers/hooks/session-start.ps1
git commit -m "fix: guard the throttle refresh with an atomic lock to close the TOCTOU race"
```

---

### Task 5: Doc-accuracy fixes — Codex-4, Codex-6, Codex-7, Codex-8, L2, L4

**Files:**
- Modify: `plugins/gigapowers/commands/status.md:2` and `:18-19`
- Modify: `plugins/gigapowers/README.md:16-17`
- Modify: `plugins/gigapowers/hooks/session-start.ps1:10`
- Modify: `plugins/gigapowers/references/codex-install.md:80-86` and after `:31`
- Modify: `plugins/gigapowers/templates/codex-config.toml:4`
- Modify: `plugins/gigapowers/commands/sync.md:16`

- [ ] **Step 1: Codex-4 — relabel "last auto-update" in `status.md`**

In `status.md`, change the frontmatter `description` (line 2) from:

```
description: Show gigapowers health — both superpowers stacks, Codex CLI and auth, last auto-update, stop-gate state
```

to:

```
description: Show gigapowers health — both superpowers stacks, Codex CLI and auth, last sync attempt, stop-gate state
```

Then replace item 5 (lines 18-19):

```markdown
5. **Last auto-update** — read `~/.gigapowers/last-sync`; report the timestamp
   and how long ago that was, or "never".
```

with:

```markdown
5. **Last sync attempt** — read `~/.gigapowers/last-sync`; report the timestamp
   and how long ago that was, or "never". This records the last *attempt*: the
   timestamp is written when the refresh is dispatched, not when it completes
   (see `hooks/session-start.ps1`), so it is not proof of a successful update.
```

- [ ] **Step 2: Codex-4 — match the wording in `README.md`**

In `README.md`, change line 16-17:

```markdown
- **`/gigapowers:status`** — health check of both stacks, Codex auth, last
  auto-update.
```

to:

```markdown
- **`/gigapowers:status`** — health check of both stacks, Codex auth, last
  sync attempt.
```

- [ ] **Step 3: Codex-6 — document the deliberate global error suppression**

In `plugins/gigapowers/hooks/session-start.ps1`, replace line 10:

```powershell
$ErrorActionPreference = 'SilentlyContinue'
```

with:

```powershell
# Hook contract (see header): never block or fail the session. Errors in here
# are not actionable for the user mid-session, so they are suppressed globally
# and the script always exits 0. Diagnose refresh problems via
# `/gigapowers:status`, not via hook output.
$ErrorActionPreference = 'SilentlyContinue'
```

- [ ] **Step 4: Codex-7 — correct the hook's readiness-check description**

In `references/codex-install.md`, replace the bullet list under "Why the hook still earns its place" (lines 81-86):

```markdown
- runs `codex plugin marketplace upgrade` defensively (cheap, covers user-added
  Git marketplaces),
- is the natural home for the readiness check (is `codex` on PATH? authed?),
- keeps a throttle timestamp so `/gigapowers:status` can report "last checked".
```

with:

```markdown
- runs `codex plugin marketplace upgrade` defensively (cheap, covers user-added
  Git marketplaces),
- does a cheap readiness check — is `codex` on `PATH`? (a missing `codex` means
  there is nothing to refresh). Auth is *not* checked here; that is
  `/gigapowers:status`'s job, via `codex login status`,
- keeps a throttle timestamp so `/gigapowers:status` can report "last checked".
```

- [ ] **Step 5: Codex-8 — add a caveat about install detection brittleness**

In `references/codex-install.md`, immediately after line 31 (the sentence ending "...added via a user Git marketplace.") and before the "**Enabled?**" line, insert:

```markdown

> **Caveat:** this check reads Codex's internal plugin-cache layout
> (`~/.codex/plugins/cache/...`), which is not a stable public contract. If a
> future codex-cli reorganizes that cache the glob will need updating. There is
> no plugin-state query API in codex-cli 0.130.0; revisit this if one ships.
```

- [ ] **Step 6: L2 — stop hard-coding the model in the config template**

Replace the body of `plugins/gigapowers/templates/codex-config.toml`:

```toml
# Project-level Codex configuration.
# Overrides ~/.codex/config.toml for work inside this project.

model = "gpt-5.3-codex"
model_reasoning_effort = "high"
```

with:

```toml
# Project-level Codex configuration.
# Overrides ~/.codex/config.toml for work inside this project.

# Pin a model only if this project genuinely needs one — otherwise leave it
# commented out and inherit whatever the user's ~/.codex/config.toml selects,
# so the project does not rot against an aging model string.
# model = "gpt-5.3-codex"

model_reasoning_effort = "high"
```

- [ ] **Step 7: L4 — guard `sync.md` against raw error-page output**

In `sync.md`, replace step 2 (line 16):

```markdown
2. Run `codex plugin marketplace upgrade` and capture the output.
```

with:

```markdown
2. Run `codex plugin marketplace upgrade` and capture both its output and exit
   code. If it exits non-zero, or the output looks like an error page rather
   than CLI output (e.g. it contains `<html` or "Cloudflare"), report a
   one-line failure summary — do not dump the raw body — and stop without
   writing the timestamp (skip steps 3-4). A network or geo failure here is not
   a reason to advance the throttle window.
```

- [ ] **Step 8: Verify**

Read each modified file back. Confirm: `status.md` + `README.md` no longer say "auto-update"; `session-start.ps1:10` has the rationale comment; `codex-install.md` describes the PATH-only readiness check and has the detection caveat; `codex-config.toml` has the `model` line commented out; `sync.md` step 2 guards against error-page output.

- [ ] **Step 9: Commit**

```bash
git add plugins/gigapowers/commands/status.md plugins/gigapowers/README.md plugins/gigapowers/hooks/session-start.ps1 plugins/gigapowers/references/codex-install.md plugins/gigapowers/templates/codex-config.toml plugins/gigapowers/commands/sync.md
git commit -m "docs: correct overclaiming wording and harden sync against error pages"
```

---

### Task 6: M2 + M3 + Codex-10 — repo hygiene (relocate dogfood, fix .gitignore)

**Files:**
- Create: `AGENTS.md` (repo root)
- Create: `CLAUDE.md` (repo root)
- Create: `.codex/config.toml` (repo root)
- Delete: `plugins/gigapowers/AGENTS.md`, `plugins/gigapowers/CLAUDE.md`, `plugins/gigapowers/.codex/` (dir), `plugins/gigapowers/.claude/` (dir)
- Modify: `.gitignore`

Background: a dogfood `/gigapowers:init` ran inside `plugins/gigapowers/` — one directory too deep. The repo root is the project (it is the marketplace; `plugins/gigapowers/` is just the plugin subdir). Relocate the scaffolded files to the root, filled out with gigapowers' real project info.

- [ ] **Step 1: Create the filled-out repo-root `AGENTS.md`**

Create `AGENTS.md` at the repo root:

```markdown
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
```

- [ ] **Step 2: Create the repo-root `CLAUDE.md`**

Create `CLAUDE.md` at the repo root (same content as `plugins/gigapowers/templates/CLAUDE.md`):

```markdown
@AGENTS.md

## Claude-specific

- Use superpowers skills for brainstorming, planning, TDD, debugging, and review.
- Use the gigapowers `orchestrating-codex` skill to bring Codex in as a peer on
  every non-trivial task — design, planning, implementation, review, debugging.
- Default Opus for architecture and tricky reasoning; Sonnet for execution.
- AGENTS.md is the single source of truth — do not duplicate its content here.
```

- [ ] **Step 3: Create the repo-root `.codex/config.toml`**

Create `.codex/config.toml` at the repo root (same content as the Task 5 / Step 6 updated `templates/codex-config.toml`):

```toml
# Project-level Codex configuration.
# Overrides ~/.codex/config.toml for work inside this project.

# Pin a model only if this project genuinely needs one — otherwise leave it
# commented out and inherit whatever the user's ~/.codex/config.toml selects,
# so the project does not rot against an aging model string.
# model = "gpt-5.3-codex"

model_reasoning_effort = "high"
```

- [ ] **Step 4: Delete the misplaced dogfood files**

```bash
git rm -r --cached --ignore-unmatch plugins/gigapowers/.claude plugins/gigapowers/.codex plugins/gigapowers/AGENTS.md plugins/gigapowers/CLAUDE.md
rm -rf plugins/gigapowers/.claude plugins/gigapowers/.codex plugins/gigapowers/AGENTS.md plugins/gigapowers/CLAUDE.md
```

(These four were untracked, so `git rm --cached` is a safe no-op for them; `rm -rf` does the actual removal. `--ignore-unmatch` keeps the command from failing on the untracked paths.)

- [ ] **Step 5: Fix `.gitignore` (M3 + Codex-10)**

Replace the entire contents of `.gitignore`:

```gitignore
# Local Claude Code settings — never committed
**/.claude/settings.local.json

# OS / editor noise
Thumbs.db
.DS_Store
*.swp
```

(Removes the `.gigapowers/` rule — Codex-10: runtime state lives in `$HOME/.gigapowers`, never in-repo, so that rule guarded nothing, as its own comment admitted. Adds `**/.claude/settings.local.json` — M3 — so local Claude settings are never committed at any depth.)

- [ ] **Step 6: Verify**

Run: `git status --short`
Expected: `AGENTS.md`, `CLAUDE.md`, `.codex/config.toml` show as new at the repo root; the `plugins/gigapowers/` dogfood paths are gone; `.gitignore` shows as modified. No `settings.local.json` appears as untracked.

Run: `git check-ignore -v plugins/gigapowers/.claude/settings.local.json` (recreate the file first if needed to test) — expected: matched by `**/.claude/settings.local.json`.

- [ ] **Step 7: Commit**

```bash
git add AGENTS.md CLAUDE.md .codex/config.toml .gitignore
git add -u plugins/gigapowers
git commit -m "chore: relocate dogfood config to repo root, fill it out, fix .gitignore"
```

---

### Task 7: L1 — single source of truth for the version, then bump to 0.2.0

**Files:**
- Create: `scripts/bump-version.mjs`
- Modify (via the script): `plugins/gigapowers/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create the version-bump script**

Create `scripts/bump-version.mjs`:

```javascript
#!/usr/bin/env node
// Single source of truth for bumping the gigapowers version.
// Usage: node scripts/bump-version.mjs <major.minor.patch>
// Rewrites every hand-maintained copy of the version: plugin.json (.version)
// and marketplace.json (.metadata.version + .plugins[0].version). Uses a
// targeted string replace so the manifests' hand-authored formatting is kept.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const version = process.argv[2];
if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
  console.error("Usage: node scripts/bump-version.mjs <major.minor.patch>");
  process.exit(1);
}

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const targets = [
  join(repoRoot, "plugins", "gigapowers", ".claude-plugin", "plugin.json"),
  join(repoRoot, ".claude-plugin", "marketplace.json"),
];

for (const file of targets) {
  const before = readFileSync(file, "utf8");
  const after = before.replace(
    /("version"\s*:\s*)"[^"]*"/g,
    `$1"${version}"`
  );
  if (after === before) {
    console.error(`No "version" key found in ${file}`);
    process.exit(1);
  }
  writeFileSync(file, after);
  console.log(`Updated ${file}`);
}

console.log(`Bumped gigapowers to ${version}.`);
```

- [ ] **Step 2: Run the script to bump to 0.2.0**

Run: `node scripts/bump-version.mjs 0.2.0`
Expected: prints `Updated ...plugin.json`, `Updated ...marketplace.json`, `Bumped gigapowers to 0.2.0.`

- [ ] **Step 3: Verify**

Run: `git diff --unified=0 plugins/gigapowers/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: exactly three changed lines — `plugin.json` `"version"` `0.1.1` → `0.2.0`, and `marketplace.json` both `"version"` occurrences (`metadata` + `plugins[0]`) `0.1.1` → `0.2.0`. No other lines changed (formatting preserved).

- [ ] **Step 4: Commit**

```bash
git add scripts/bump-version.mjs plugins/gigapowers/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: add bump-version script and bump gigapowers to 0.2.0"
```

---

## Self-Review

**Spec coverage** — every merged finding maps to a task:
- H1 → Task 2 (SKILL.md reword). H2 → Task 1. M1 → Task 3. M2 → Task 6. M3 → Task 6. Codex-2 → Task 2 (init.md verify). L1 → Task 7. L2 → Task 5/Step 6. L3 → Task 4. L4 → Task 5/Step 7. Codex-4 → Task 5/Steps 1-2. Codex-6 → Task 5/Step 3. Codex-7 → Task 5/Step 4. Codex-8 → Task 5/Step 5. Codex-10 → Task 6/Step 5.
- `references/codex-install.md:3` (L2 / Codex-9 second half) is intentionally **not** changed — see "Decisions already made"; it is dated provenance, not rot.

**Placeholder scan** — no TBD / "add error handling" / "similar to Task N" / undefined symbols. All code and prose shown in full.

**Type consistency** — `Test-AcquireSyncLock -LockFile` (Task 4 Step 3) is called with `-LockFile` everywhere (test Step 1, session-start.ps1 Step 5). `Remove-SyncLock -TimestampFile` is called with `-TimestampFile` everywhere (test Step 1, session-start.ps1 Step 5) — the parameter name is deliberately `-TimestampFile` to match `Test-SyncStale` / `Write-SyncTimestamp`, and Step 1's note flags this so a reader does not "fix" it to `-LockFile`. The `bump-version.mjs` regex `/("version"\s*:\s*)"[^"]*"/g` matches the actual formatting in both manifests (`"version": "0.1.1"`).

**Ordering note** — Task 5/Step 6 and Task 6/Step 3 write the same `codex-config.toml` content (template vs. repo-root copy); both are shown in full because tasks may be executed or reviewed out of order.
