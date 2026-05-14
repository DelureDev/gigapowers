# Gigapowers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `gigapowers` Claude Code plugin — a peer-collaboration layer that bootstraps both superpowers stacks per project, keeps the Codex-side install current, and carries the Claude-vs-Codex orchestration brain.

**Architecture:** A single Claude Code plugin shipped from a marketplace repo. It owns three commands, one skill (the brain), one throttled SessionStart hook, and three project templates. It builds on the existing `codex@openai-codex` plugin surfaces Claude can invoke (the `codex-rescue` agent, `codex:rescue`/`codex:setup` skills, the stop-gate hook, and `codex exec`) — it reimplements none of them. The Claude-side superpowers auto-update is left entirely to Claude Code; only the Codex side needs a bridge.

**Tech Stack:** Markdown (skills, commands), JSON (plugin/marketplace/hooks manifests), PowerShell 5.1 (the SessionStart hook + its unit test), `gh` CLI (repo creation), `codex` CLI 0.130.0 (Codex-side plugin management).

**Environment note:** `gh` is installed at `C:\Program Files\GitHub CLI\gh.exe` but is **not on this session's PATH** — always invoke it by full path. Repo target: `github.com/DelureDev/gigapowers`. Working dir: `C:\Pyth\gigapowers` (git already initialized on `main`).

---

## File Structure

```
gigapowers/                                         # repo root = marketplace
  .claude-plugin/marketplace.json                   # Task 1
  LICENSE                                           # Task 1
  .gitignore                                        # Task 1
  README.md                                         # Task 9
  tests/throttle.tests.ps1                          # Task 3  (root — not shipped in plugin)
  docs/superpowers/specs/2026-05-14-gigapowers-design.md   # exists
  docs/superpowers/plans/2026-05-14-gigapowers-implementation.md  # this file
  plugins/gigapowers/                               # the plugin (this is what installs)
    .claude-plugin/plugin.json                      # Task 1
    README.md                                       # Task 9
    references/codex-install.md                     # Task 2
    hooks/lib/throttle.ps1                          # Task 3
    hooks/session-start.ps1                         # Task 4
    hooks/hooks.json                                # Task 4
    skills/orchestrating-codex/SKILL.md             # Task 5
    templates/AGENTS.md                             # Task 6
    templates/CLAUDE.md                             # Task 6
    templates/codex-config.toml                     # Task 6
    commands/init.md                                # Task 7
    commands/status.md                              # Task 8
    commands/sync.md                                # Task 8
```

Responsibilities: `marketplace.json` advertises the plugin; `plugin.json` is the plugin manifest; `throttle.ps1` is pure testable logic (staleness + timestamp write); `session-start.ps1` is the hook entry point (orchestrates throttle + background upgrade); `hooks.json` registers it; `orchestrating-codex/SKILL.md` is the brain; `templates/` feed `/gigapowers:init`; the three `commands/` are the user-facing surface; `references/codex-install.md` is the resolved Codex install recipe consumed by `init.md`.

---

## Task 1: Repo scaffold + manifests

**Files:**
- Create: `C:\Pyth\gigapowers\.claude-plugin\marketplace.json`
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\.claude-plugin\plugin.json`
- Create: `C:\Pyth\gigapowers\LICENSE`
- Create: `C:\Pyth\gigapowers\.gitignore`

- [ ] **Step 1: Create the directory tree**

Run:
```powershell
cd C:\Pyth\gigapowers
$dirs = @(
  '.claude-plugin',
  'plugins\gigapowers\.claude-plugin',
  'plugins\gigapowers\hooks\lib',
  'plugins\gigapowers\skills\orchestrating-codex',
  'plugins\gigapowers\templates',
  'plugins\gigapowers\commands',
  'plugins\gigapowers\references',
  'tests'
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
Get-ChildItem -Recurse -Directory | Select-Object -ExpandProperty FullName
```
Expected: all eight directories listed.

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "gigapowers",
  "owner": {
    "name": "DelureDev"
  },
  "metadata": {
    "description": "Gigapowers — a peer-collaboration layer that orchestrates Claude Code + Codex on every project.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "gigapowers",
      "description": "Makes Claude and Codex build as peers: per-project bootstrap of both superpowers stacks, Codex-side auto-update, and the Claude-vs-Codex orchestration brain.",
      "version": "0.1.0",
      "author": { "name": "DelureDev" },
      "source": "./plugins/gigapowers"
    }
  ]
}
```

- [ ] **Step 3: Write `plugins/gigapowers/.claude-plugin/plugin.json`**

```json
{
  "name": "gigapowers",
  "version": "0.1.0",
  "description": "Makes Claude and Codex build as peers: per-project bootstrap of both superpowers stacks, Codex-side auto-update, and the Claude-vs-Codex orchestration brain.",
  "author": {
    "name": "DelureDev",
    "url": "https://github.com/DelureDev"
  },
  "homepage": "https://github.com/DelureDev/gigapowers",
  "repository": "https://github.com/DelureDev/gigapowers",
  "license": "MIT",
  "keywords": ["codex", "orchestration", "superpowers", "workflow", "collaboration"]
}
```

- [ ] **Step 4: Write `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 DelureDev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Write `.gitignore`**

```
# Gigapowers state (created at runtime under the user's home dir, never in-repo)
.gigapowers/

# OS / editor noise
Thumbs.db
.DS_Store
*.swp
```

- [ ] **Step 6: Verify all JSON parses**

Run:
```powershell
cd C:\Pyth\gigapowers
Get-Content .claude-plugin\marketplace.json -Raw | ConvertFrom-Json | Out-Null; "marketplace.json OK"
Get-Content plugins\gigapowers\.claude-plugin\plugin.json -Raw | ConvertFrom-Json | Out-Null; "plugin.json OK"
```
Expected: `marketplace.json OK` then `plugin.json OK`, no exceptions.

- [ ] **Step 7: Commit**

```powershell
cd C:\Pyth\gigapowers
git add .claude-plugin LICENSE .gitignore plugins/gigapowers/.claude-plugin
git -c commit.gpgsign=false commit -m "feat: scaffold gigapowers marketplace + plugin manifests"
```

---

## Task 2: Resolve the Codex superpowers install mechanism

The one open question from the spec (§10). Resolve it experimentally and write the recipe into a reference file the `/gigapowers:init` command will consume.

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\references\codex-install.md`

- [ ] **Step 1: Inspect what Codex plugin subcommands actually exist**

Run:
```powershell
codex plugin --help
codex plugin marketplace --help
```
Expected: confirms `marketplace` with `add` / `upgrade` / `remove`. Note whether any `install`/`list`/`enable` subcommand exists.

- [ ] **Step 2: Add the official Codex plugin marketplace**

Run:
```powershell
codex plugin marketplace add openai/plugins
```
Expected: success message that the `openai/plugins` marketplace was added/cloned. If it errors, capture the exact error.

- [ ] **Step 3: Discover how a plugin from the marketplace gets enabled**

Run:
```powershell
# Inspect what landed after `add`
Get-ChildItem $HOME\.codex\.tmp\plugins -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object FullName
Get-Content $HOME\.codex\config.toml -Raw
Get-ChildItem $HOME\.codex\skills -ErrorAction SilentlyContinue | Select-Object Name
```
Expected: identifies whether superpowers skills now appear under `~/.codex/skills/`, OR whether an explicit enable step (a `config.toml` `[plugins]` entry, or a `codex plugin` subcommand) is required. If an enable step is needed, perform it and re-run the `Get-ChildItem $HOME\.codex\skills` check until superpowers skills (e.g. a `brainstorming` directory) are present.

- [ ] **Step 4: Confirm superpowers is live in Codex**

Run:
```powershell
Get-ChildItem $HOME\.codex\skills | Where-Object Name -in @('brainstorming','test-driven-development','writing-plans') | Select-Object Name
```
Expected: at least `brainstorming` listed. If not, the recipe is not yet resolved — repeat Step 3 with the alternative mechanism observed.

- [ ] **Step 5: Write the resolved recipe to `references/codex-install.md`**

Write the file using the **exact commands that worked** in Steps 2–4. Use this structure (fill the fenced blocks with the verified commands, not placeholders):

```markdown
# Installing superpowers into Codex

Resolved 2026-05-14 against codex-cli 0.130.0.

## Check if already installed

Superpowers is present in Codex when `~/.codex/skills/` contains a
`brainstorming` directory.

## Install (run only if missing)

<the verified `codex plugin marketplace add ...` command>

<the verified enable step, if one was required — otherwise state "no enable
step needed; `add` makes the skills live">

## Verify

<the verified `Get-ChildItem ~/.codex/skills` check and its expected output>

## Update

`codex plugin marketplace upgrade` refreshes all added marketplaces, including
superpowers. This is what the gigapowers SessionStart hook runs on a 24h throttle.
```

- [ ] **Step 6: Verify the reference file is complete**

Run:
```powershell
Get-Content C:\Pyth\gigapowers\plugins\gigapowers\references\codex-install.md -Raw |
  Select-String -Pattern 'TODO|TBD|<the verified' -Quiet
```
Expected: `False` (no unfilled placeholders remain).

- [ ] **Step 7: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/references/codex-install.md
git -c commit.gpgsign=false commit -m "feat: resolve and document the Codex superpowers install recipe"
```

---

## Task 3: Throttle library + unit test (TDD)

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\hooks\lib\throttle.ps1`
- Test: `C:\Pyth\gigapowers\tests\throttle.tests.ps1`

- [ ] **Step 1: Write the failing test**

Create `tests/throttle.tests.ps1`:
```powershell
# Plain-PowerShell unit test for hooks/lib/throttle.ps1.
# No Pester dependency (PS 5.1's bundled Pester is too old to rely on).
# Exits 1 on any failure, 0 when all pass.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../plugins/gigapowers/hooks/lib/throttle.ps1"

$script:failures = 0
function Assert-Equal($expected, $actual, $name) {
    if ($expected -ne $actual) {
        Write-Host "FAIL: $name -- expected [$expected], got [$actual]" -ForegroundColor Red
        $script:failures++
    } else {
        Write-Host "PASS: $name" -ForegroundColor Green
    }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gp-throttle-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $now = Get-Date '2026-05-14T12:00:00'

    Assert-Equal $true (Test-SyncStale -TimestampFile "$tmp/missing" -Now $now) 'missing file is stale'

    $fresh = "$tmp/fresh"; ($now.AddHours(-1)).ToString('o') | Set-Content $fresh
    Assert-Equal $false (Test-SyncStale -TimestampFile $fresh -Now $now) 'fresh (1h) file not stale'

    $old = "$tmp/old"; ($now.AddHours(-25)).ToString('o') | Set-Content $old
    Assert-Equal $true (Test-SyncStale -TimestampFile $old -Now $now) 'old (25h) file is stale'

    $edge = "$tmp/edge"; ($now.AddHours(-24)).ToString('o') | Set-Content $edge
    Assert-Equal $true (Test-SyncStale -TimestampFile $edge -Now $now) '24h boundary is stale'

    $corrupt = "$tmp/corrupt"; 'not-a-date' | Set-Content $corrupt
    Assert-Equal $true (Test-SyncStale -TimestampFile $corrupt -Now $now) 'corrupt file is stale'

    $empty = "$tmp/empty"; '' | Set-Content $empty
    Assert-Equal $true (Test-SyncStale -TimestampFile $empty -Now $now) 'empty file is stale'

    $nested = "$tmp/a/b/last-sync"
    Write-SyncTimestamp -TimestampFile $nested -Now $now
    Assert-Equal $true (Test-Path $nested) 'Write-SyncTimestamp creates nested dirs + file'
    Assert-Equal $false (Test-SyncStale -TimestampFile $nested -Now $now) 'just-written timestamp not stale'
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($script:failures -gt 0) {
    Write-Host "$script:failures test(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "All throttle tests passed" -ForegroundColor Green
exit 0
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Pyth\gigapowers\tests\throttle.tests.ps1
```
Expected: FAIL — dot-sourcing throws because `hooks/lib/throttle.ps1` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `plugins/gigapowers/hooks/lib/throttle.ps1`:
```powershell
# Gigapowers throttle helpers. Dot-sourced by session-start.ps1 and the tests.
# Defines functions only -- no side effects on load.

function Test-SyncStale {
    <#
      Returns $true when the Codex-side update should run:
      the timestamp file is missing, empty, unparseable, or at least
      $MaxAgeHours old.
    #>
    param(
        [Parameter(Mandatory)][string]$TimestampFile,
        [datetime]$Now = (Get-Date),
        [int]$MaxAgeHours = 24
    )
    if (-not (Test-Path -LiteralPath $TimestampFile)) { return $true }
    $raw = Get-Content -LiteralPath $TimestampFile -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) { return $true }
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($raw.Trim(), [ref]$parsed)) { return $true }
    return ($Now - $parsed).TotalHours -ge $MaxAgeHours
}

function Write-SyncTimestamp {
    <#
      Writes $Now as an ISO 8601 'o' string to $TimestampFile, creating the
      parent directory if needed.
    #>
    param(
        [Parameter(Mandatory)][string]$TimestampFile,
        [datetime]$Now = (Get-Date)
    )
    $dir = Split-Path -Parent $TimestampFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Now.ToString('o') | Set-Content -LiteralPath $TimestampFile -Encoding utf8
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Pyth\gigapowers\tests\throttle.tests.ps1
```
Expected: 8 `PASS` lines, then `All throttle tests passed`, exit code 0.

- [ ] **Step 5: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/hooks/lib/throttle.ps1 tests/throttle.tests.ps1
git -c commit.gpgsign=false commit -m "feat: add throttle helpers with unit tests"
```

---

## Task 4: SessionStart hook script + registration

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\hooks\session-start.ps1`
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\hooks\hooks.json`

- [ ] **Step 1: Write `hooks/session-start.ps1`**

```powershell
# Gigapowers SessionStart hook.
# Throttled (24h) Codex-side superpowers update + cheap readiness check.
# Windows-first. Never blocks the session; never exits non-zero.

$ErrorActionPreference = 'SilentlyContinue'

. "$PSScriptRoot/lib/throttle.ps1"

$stateDir = Join-Path $HOME '.gigapowers'
$stamp    = Join-Path $stateDir 'last-sync'

# Readiness check: if Codex is not on PATH there is nothing to update.
# Stay silent -- a missing Codex is the user's choice, not a hook error.
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) { exit 0 }

# Throttled update. The timestamp is written on *dispatch*, not completion:
# if the upgrade fails (e.g. offline) the next attempt is the following stale
# window. This is the documented v1 tradeoff (spec section 8).
if (Test-SyncStale -TimestampFile $stamp) {
    # Detach the slow upgrade so session start is never blocked.
    Start-Process -WindowStyle Hidden -FilePath $codex.Source `
        -ArgumentList 'plugin','marketplace','upgrade' -ErrorAction SilentlyContinue
    Write-SyncTimestamp -TimestampFile $stamp
}

exit 0
```

- [ ] **Step 2: Write `hooks/hooks.json`**

```json
{
  "description": "Gigapowers — throttled Codex-side superpowers auto-update + readiness check.",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.ps1\"",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Verify hooks.json parses and the script runs clean**

Run:
```powershell
Get-Content C:\Pyth\gigapowers\plugins\gigapowers\hooks\hooks.json -Raw | ConvertFrom-Json | Out-Null; "hooks.json OK"
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Pyth\gigapowers\plugins\gigapowers\hooks\session-start.ps1
"exit code: $LASTEXITCODE"
Test-Path $HOME\.gigapowers\last-sync
```
Expected: `hooks.json OK`, hook runs with `exit code: 0`, and `True` (the timestamp file was created — proves the throttle dispatched once).

- [ ] **Step 4: Verify the throttle now suppresses a second run**

Run:
```powershell
$before = (Get-Item $HOME\.gigapowers\last-sync).LastWriteTime
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Pyth\gigapowers\plugins\gigapowers\hooks\session-start.ps1
$after = (Get-Item $HOME\.gigapowers\last-sync).LastWriteTime
"timestamp unchanged: $($before -eq $after)"
```
Expected: `timestamp unchanged: True` — the second run saw a fresh timestamp and did nothing.

- [ ] **Step 5: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/hooks/session-start.ps1 plugins/gigapowers/hooks/hooks.json
git -c commit.gpgsign=false commit -m "feat: add throttled SessionStart hook for Codex-side updates"
```

---

## Task 5: The `orchestrating-codex` skill (the brain)

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\skills\orchestrating-codex\SKILL.md`

- [ ] **Step 1: Write `skills/orchestrating-codex/SKILL.md`**

```markdown
---
name: orchestrating-codex
description: Use when working on any non-trivial task with Claude as the driver - decides when and how to bring Codex in as a peer collaborator across design, planning, implementation, review, and debugging
---

# Orchestrating Codex

Codex is your peer. Not a linter, not a rubber stamp — a collaborator with a
different model, different training, and genuinely different blind spots. On
every non-trivial task Codex gets a seat at the table. Your job is to make the
collaboration *substantive*, not ceremonial.

## When to bring Codex in

| Stage | What Codex does | How |
|-------|-----------------|-----|
| Design / brainstorm | Stress-tests an approach when 2+ are viable | `codex exec` consult |
| Planning | Reads the plan for gaps and missed edge cases | `codex exec` consult |
| Implementation | Takes parallel batch work; second opinion on a tricky unit | `codex:codex-rescue` agent |
| Before "done" | Adversarial review of the diff | codex plugin's Stop gate (automatic) |
| Stuck (2+ failed debug rounds) | Fresh-context diagnosis | `codex:codex-rescue` agent |

You decide the judgment-call rows. The Stop-gate row fires automatically — do
not duplicate it.

## How to consult Codex (the part that matters)

A weak consult — "here's my code, looks good right?" — invites validation and
wastes the call. A strong consult gives Codex what it needs to *disagree well*:

1. **Context** — the goal, the constraints, what you already tried.
2. **The artifact** — the actual diff / plan / approach, not a summary of it.
3. **An adversarial ask** — "What's wrong with this? What breaks it? What would
   you have done differently?" Never "is this OK?"

Example:
\`\`\`
codex exec "Reviewing a design decision. Goal: <...>. Constraints: <...>.
I'm leaning toward approach A: <...>. Approach B was: <...>.
What's wrong with A? What does B get right that A misses? Be specific and brief."
\`\`\`

## Reconciling what Codex says

- **Clear win** — Codex is right and the fix is obvious → fix it, note it.
- **Judgment call** — reasonable people could disagree → surface it to the user:
  "Codex flagged X — fix? skip?"
- **Codex is wrong** — you verified it misread something → say so plainly. Do
  not perform agreement. (See superpowers:receiving-code-review.)

Disagreement between you and Codex is the *product*, not a failure. Two models
that always agree add nothing over one.

## Don't call Codex for

- Trivial edits — typos, formatting, one-liners, comments.
- Doc-only changes.
- When the user said "skip codex" / "no review needed".
- Recursively — one Codex round per task lifecycle. Never loop
  Claude → Codex → Claude → Codex on the same artifact.
- When superpowers:requesting-code-review is already running for this work.

## Invocation mechanics

- **`codex:codex-rescue` agent** (via the Agent tool) — for substantial work:
  batch implementation, deep diagnosis, a full second-opinion pass.
- **`codex exec "..."`** (via the shell) — for lightweight inline consults
  during design and planning.
- **Never type `/codex:*` slash commands** — those are user-only. If the user
  should run one, tell them to.
- Announce before calling: one sentence — "Consulting Codex for <reason>."
- Cost awareness: each call burns ChatGPT Pro quota. Call when it adds value,
  not as ritual.
```

Note: in the example fenced block above, the triple backticks are escaped as `\`\`\`` only in this plan document. In the actual `SKILL.md` file, write them as normal triple backticks.

- [ ] **Step 2: Verify the skill file is well-formed**

Run:
```powershell
$content = Get-Content C:\Pyth\gigapowers\plugins\gigapowers\skills\orchestrating-codex\SKILL.md -Raw
$content.StartsWith("---") -and ($content -match "(?s)^---.*?name: orchestrating-codex.*?description:.*?---")
```
Expected: `True` — frontmatter present with `name` and `description`.

- [ ] **Step 3: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/skills/orchestrating-codex/SKILL.md
git -c commit.gpgsign=false commit -m "feat: add orchestrating-codex skill (the orchestration brain)"
```

---

## Task 6: Project templates

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\templates\AGENTS.md`
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\templates\CLAUDE.md`
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\templates\codex-config.toml`

- [ ] **Step 1: Write `templates/AGENTS.md`**

```markdown
# Project: <PROJECT_NAME>

> Single source of truth for both Claude and Codex. CLAUDE.md imports this file;
> do not duplicate content between them.

## Stack
- Language + version:
- Frameworks:
- Tooling (lint, format, type check, test):

## Conventions
- Test command:
- Lint / format command:
- Commit style: Conventional Commits
- Branch naming: <type>/<short-description>

## Domain
- What this project does:
- Key concepts / glossary:

## Don't
- No secrets or PII in logs or commits.
- No new SaaS or network dependencies without approval.
- No `--dangerously-skip-permissions`.
```

- [ ] **Step 2: Write `templates/CLAUDE.md`**

```markdown
@AGENTS.md

## Claude-specific

- Use superpowers skills for brainstorming, planning, TDD, debugging, and review.
- Use the gigapowers `orchestrating-codex` skill to bring Codex in as a peer on
  every non-trivial task — design, planning, implementation, review, debugging.
- Default Opus for architecture and tricky reasoning; Sonnet for execution.
- AGENTS.md is the single source of truth — do not duplicate its content here.
```

- [ ] **Step 3: Write `templates/codex-config.toml`**

```toml
# Project-level Codex configuration.
# Overrides ~/.codex/config.toml for work inside this project.

model = "gpt-5.3-codex"
model_reasoning_effort = "high"
```

- [ ] **Step 4: Verify all three templates exist and are non-empty**

Run:
```powershell
'AGENTS.md','CLAUDE.md','codex-config.toml' | ForEach-Object {
  $p = "C:\Pyth\gigapowers\plugins\gigapowers\templates\$_"
  "{0}: {1} bytes" -f $_, (Get-Item $p).Length
}
```
Expected: three lines, each with a byte count greater than 0.

- [ ] **Step 5: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/templates
git -c commit.gpgsign=false commit -m "feat: add AGENTS.md / CLAUDE.md / codex-config.toml templates"
```

---

## Task 7: `/gigapowers:init` command

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\commands\init.md`

- [ ] **Step 1: Write `commands/init.md`**

```markdown
---
description: Bootstrap a project for the gigapowers workflow — verify both superpowers stacks, scaffold AGENTS.md / CLAUDE.md / .codex config, ensure git and the Codex stop-gate
argument-hint: '[--force]'
allowed-tools: Bash, Read, Write, Skill, AskUserQuestion
---

Bootstrap the current project for the gigapowers Claude + Codex workflow.

`$ARGUMENTS` may contain `--force` — when present, overwrite an existing
AGENTS.md / CLAUDE.md / .codex/config.toml instead of skipping it.

Run these steps in order. Report what you did or skipped for each.

## 1. Verify Claude-side superpowers
Read `~/.claude/plugins/installed_plugins.json` and look for
`superpowers@claude-plugins-official`.
- Present → report the installed version.
- Missing → tell the user to run `/plugin install superpowers@claude-plugins-official`.

## 2. Verify Codex-side superpowers
Check whether `~/.codex/skills/` contains a `brainstorming` directory.
- Present → report OK.
- Missing → follow `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md` to
  install it, then re-check.

## 3. Scaffold AGENTS.md
If `AGENTS.md` is absent (or `--force` was passed), write it from
`${CLAUDE_PLUGIN_ROOT}/templates/AGENTS.md`. Otherwise skip and say so.

## 4. Scaffold CLAUDE.md
If `CLAUDE.md` is absent (or `--force` was passed), write it from
`${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md`. Otherwise skip and say so.

## 5. Scaffold .codex/config.toml
If `.codex/config.toml` is absent (or `--force` was passed), create the `.codex/`
directory and write the file from `${CLAUDE_PLUGIN_ROOT}/templates/codex-config.toml`.
Otherwise skip and say so.

## 6. Ensure git
If `git rev-parse --is-inside-work-tree` fails, run `git init` then
`git branch -M main`.

## 7. Ensure the Codex stop-gate
Invoke the `codex:setup` skill to confirm Codex is installed and authenticated
and that the stop-time review gate is enabled.

## 8. Summary
Print a table with one row per step above: the step name and whether it was
done, skipped, or needs user action.
```

- [ ] **Step 2: Verify frontmatter is well-formed**

Run:
```powershell
$c = Get-Content C:\Pyth\gigapowers\plugins\gigapowers\commands\init.md -Raw
$c -match "(?s)^---.*?description:.*?allowed-tools:.*?---"
```
Expected: `True`.

- [ ] **Step 3: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/commands/init.md
git -c commit.gpgsign=false commit -m "feat: add /gigapowers:init bootstrap command"
```

---

## Task 8: `/gigapowers:status` and `/gigapowers:sync` commands

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\commands\status.md`
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\commands\sync.md`

- [ ] **Step 1: Write `commands/status.md`**

```markdown
---
description: Show gigapowers health — both superpowers stacks, Codex CLI and auth, last auto-update, stop-gate state
allowed-tools: Bash, Read
---

Report gigapowers health. This command is read-only — change nothing.

1. **Claude-side superpowers** — read `~/.claude/plugins/installed_plugins.json`;
   report the `superpowers@claude-plugins-official` version, or "not installed".
2. **Codex-side superpowers** — check `~/.codex/skills/` for a `brainstorming`
   directory; report present or absent.
3. **Codex CLI** — run `codex --version`; report the version, or "not installed".
4. **Codex auth** — check whether `~/.codex/auth.json` exists; report
   authenticated or not.
5. **Last auto-update** — read `~/.gigapowers/last-sync`; report the timestamp
   and how long ago that was, or "never".
6. **Stop-gate** — report whether the codex plugin's stop-review gate is
   enabled (use `codex:setup` state if available, otherwise note "run
   /gigapowers:init or codex:setup to confirm").

Print a compact status table, one row per item.
```

- [ ] **Step 2: Write `commands/sync.md`**

```markdown
---
description: Force an immediate Codex-side superpowers update and refresh the throttle timestamp
allowed-tools: Bash, Read, Write
---

Force the Codex-side superpowers update now, bypassing the 24h throttle.

1. If `codex` is not installed or `~/.codex/auth.json` is missing, report that
   clearly and stop — do not write the timestamp.
2. Run `codex plugin marketplace upgrade` and capture the output.
3. Write the current timestamp (ISO 8601, e.g. the output of
   `(Get-Date).ToString('o')`) to `~/.gigapowers/last-sync`, creating the
   `~/.gigapowers/` directory if needed.
4. Report what `upgrade` did and the new timestamp.
```

- [ ] **Step 3: Verify both frontmatters are well-formed**

Run:
```powershell
'status.md','sync.md' | ForEach-Object {
  $c = Get-Content "C:\Pyth\gigapowers\plugins\gigapowers\commands\$_" -Raw
  "{0}: {1}" -f $_, ($c -match "(?s)^---.*?description:.*?---")
}
```
Expected: `status.md: True` and `sync.md: True`.

- [ ] **Step 4: Commit**

```powershell
cd C:\Pyth\gigapowers
git add plugins/gigapowers/commands/status.md plugins/gigapowers/commands/sync.md
git -c commit.gpgsign=false commit -m "feat: add /gigapowers:status and /gigapowers:sync commands"
```

---

## Task 9: READMEs

**Files:**
- Create: `C:\Pyth\gigapowers\plugins\gigapowers\README.md`
- Create: `C:\Pyth\gigapowers\README.md`

- [ ] **Step 1: Write `plugins/gigapowers/README.md`**

```markdown
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
- **`/gigapowers:sync`** — force a Codex-side superpowers update now.
- **`orchestrating-codex` skill** — the brain: when and how Claude brings Codex
  in across design, planning, implementation, review, and debugging.
- **SessionStart hook** — throttled (24h) Codex-side superpowers auto-update.
  The Claude side is handled by Claude Code itself.

## Install

\`\`\`
claude plugin marketplace add DelureDev/gigapowers
claude plugin install gigapowers@gigapowers
\`\`\`

Then in any project: `/gigapowers:init`.

## Requirements

- Claude Code with the `superpowers` and `codex@openai-codex` plugins.
- Codex CLI (`codex`) installed and authenticated.
- Windows (the SessionStart hook is PowerShell; a bash fallback is planned).

## License

MIT — see [LICENSE](../../LICENSE).
```

Note: in the actual file, write the install fenced block with normal triple
backticks (escaped here only for this plan document).

- [ ] **Step 2: Write the root `README.md`**

```markdown
# Gigapowers — marketplace

This repo is a Claude Code plugin marketplace. It ships one plugin:
**[gigapowers](./plugins/gigapowers)** — a peer-collaboration layer that
orchestrates Claude Code + Codex on every project.

## Install

\`\`\`
claude plugin marketplace add DelureDev/gigapowers
claude plugin install gigapowers@gigapowers
\`\`\`

See [plugins/gigapowers/README.md](./plugins/gigapowers/README.md) for full
documentation, and [docs/superpowers/](./docs/superpowers/) for the design spec
and implementation plan.

## License

MIT — see [LICENSE](./LICENSE).
```

Note: write the fenced blocks with normal triple backticks in the actual files.

- [ ] **Step 3: Verify both READMEs exist and are non-empty**

Run:
```powershell
'C:\Pyth\gigapowers\README.md','C:\Pyth\gigapowers\plugins\gigapowers\README.md' | ForEach-Object {
  "{0}: {1} bytes" -f $_, (Get-Item $_).Length
}
```
Expected: two lines, each with a byte count greater than 0.

- [ ] **Step 4: Commit**

```powershell
cd C:\Pyth\gigapowers
git add README.md plugins/gigapowers/README.md
git -c commit.gpgsign=false commit -m "docs: add marketplace and plugin READMEs"
```

---

## Task 10: End-to-end local verification

Install the plugin from the local marketplace and validate it loads cleanly.

- [ ] **Step 1: Check for a built-in plugin validator**

Run:
```powershell
claude plugin --help
```
Expected: lists plugin subcommands. Note whether a `validate` subcommand exists.
If it does, run `claude plugin validate C:\Pyth\gigapowers` and fix anything it
reports before continuing.

- [ ] **Step 2: Add the local marketplace and install the plugin**

Run:
```powershell
claude plugin marketplace add C:\Pyth\gigapowers
claude plugin install gigapowers@gigapowers
```
Expected: marketplace added, plugin installed without error.

- [ ] **Step 3: Confirm the install landed**

Run:
```powershell
Get-Content $HOME\.claude\plugins\installed_plugins.json -Raw | ConvertFrom-Json |
  Select-Object -ExpandProperty plugins |
  Select-Object -ExpandProperty 'gigapowers@gigapowers' -ErrorAction SilentlyContinue
```
Expected: an entry for `gigapowers@gigapowers` with an `installPath`. Inspect
that `installPath` and confirm `commands/`, `skills/orchestrating-codex/`,
`hooks/hooks.json`, `templates/`, and `references/` are all present.

- [ ] **Step 4: Dry-run `/gigapowers:init` logic in a scratch project**

The slash command is not live in this session, so exercise its *logic*
manually against a throwaway directory:
```powershell
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("gp-init-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $scratch | Out-Null
$tpl = "$HOME\.claude\plugins\cache\gigapowers\gigapowers\*\plugins\gigapowers\templates"
$tplDir = (Get-ChildItem $tpl -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if (-not $tplDir) { $tplDir = "C:\Pyth\gigapowers\plugins\gigapowers\templates" }
Copy-Item "$tplDir\AGENTS.md" "$scratch\AGENTS.md"
Copy-Item "$tplDir\CLAUDE.md" "$scratch\CLAUDE.md"
New-Item -ItemType Directory -Path "$scratch\.codex" | Out-Null
Copy-Item "$tplDir\codex-config.toml" "$scratch\.codex\config.toml"
git -C $scratch init -q
Get-ChildItem -Recurse -Force $scratch | Select-Object FullName
Remove-Item -Recurse -Force $scratch
```
Expected: `AGENTS.md`, `CLAUDE.md`, `.codex/config.toml`, and `.git/` all
present in the scratch dir before cleanup. This confirms the templates are
copyable and well-formed.

- [ ] **Step 5: Run the throttle test suite once more as a regression check**

Run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Pyth\gigapowers\tests\throttle.tests.ps1
"exit: $LASTEXITCODE"
```
Expected: `All throttle tests passed`, `exit: 0`.

- [ ] **Step 6: Fix and commit any issues found**

If Steps 1–5 surfaced problems, fix them, re-run the failing step, then:
```powershell
cd C:\Pyth\gigapowers
git add -A
git -c commit.gpgsign=false commit -m "fix: address issues found in end-to-end verification"
```
If nothing needed fixing, skip the commit and note "verification clean".

---

## Task 11: Codex adversarial review + publish

- [ ] **Step 1: Generate the full diff for review**

Run:
```powershell
cd C:\Pyth\gigapowers
git log --oneline
git diff --stat $(git rev-list --max-parents=0 HEAD) HEAD
```
Expected: the full commit history of the build and a file-change summary.

- [ ] **Step 2: Hand the diff to Codex for adversarial review**

Run (one invocation; replace the diff placeholder with the actual output of
`git diff $(git rev-list --max-parents=0 HEAD) HEAD`):
```powershell
codex exec "Review this diff adversarially. It is a Claude Code plugin called gigapowers that orchestrates Claude + Codex collaboration. Find: hook race conditions, PowerShell portability bugs, throttle-logic edge cases, JSON schema mistakes, security issues, and design smells. Be specific and brief.

<paste git diff here>"
```
Expected: a list of findings from Codex.

- [ ] **Step 3: Triage and address findings**

For each finding:
- **Clear bug** → fix it, re-run the relevant verification step from Task 10.
- **Judgment call** → note it in the final report for the user to decide;
  do not block publishing on it.
Commit any fixes:
```powershell
cd C:\Pyth\gigapowers
git add -A
git -c commit.gpgsign=false commit -m "fix: address Codex adversarial review findings"
```

- [ ] **Step 4: Create the GitHub repo and push**

Run (full path to `gh` — it is not on this session's PATH):
```powershell
cd C:\Pyth\gigapowers
& "C:\Program Files\GitHub CLI\gh.exe" repo create DelureDev/gigapowers --public --source=. --remote=origin --push --description "Gigapowers — a peer-collaboration layer that orchestrates Claude Code + Codex on every project."
```
Expected: repo created at `https://github.com/DelureDev/gigapowers` and `main`
pushed.

- [ ] **Step 5: Confirm the push**

Run:
```powershell
cd C:\Pyth\gigapowers
git remote -v
git status -sb
& "C:\Program Files\GitHub CLI\gh.exe" repo view DelureDev/gigapowers --json url,visibility,pushedAt
```
Expected: `origin` points at the new repo, working tree clean and up to date
with `origin/main`, and the repo view confirms it is public with a recent
`pushedAt`.

- [ ] **Step 6: Final report to the user**

Summarize: what was built, the commit count, Codex review findings (addressed
vs. flagged-for-user), the repo URL, and the next action for the user — install
with `claude plugin marketplace add DelureDev/gigapowers` then
`claude plugin install gigapowers@gigapowers`, restart Claude Code, and run
`/gigapowers:init` in a project.

---

## Self-Review

**1. Spec coverage** — every spec section maps to a task:
- §5 repo layout → Task 1 (+ all file-creation tasks)
- §6.1 orchestrating-codex skill → Task 5
- §6.2 `/gigapowers:init` → Task 7 (depends on Task 2 recipe + Task 6 templates)
- §6.3 `/gigapowers:status` → Task 8
- §6.4 `/gigapowers:sync` → Task 8
- §6.5 hooks → Tasks 3 (throttle lib) + 4 (hook + registration)
- §6.6 templates → Task 6
- §8 error handling → covered in `session-start.ps1` (Codex-absent exit 0,
  dispatch-time timestamp), `status.md` (not-installed/not-authed reporting),
  `sync.md` (auth precheck), throttle tests (missing/corrupt/empty)
- §9 testing strategy → Task 3 (unit), Task 10 (end-to-end), Task 11 (adversarial)
- §10 open question (Codex install incantation) → Task 2 resolves it

**2. Placeholder scan** — the only intentional fill-ins are in Task 2 Step 5
(the recipe must be written from *verified* commands — Step 6 asserts no
placeholders remain) and Task 11 Step 2 (the actual diff is pasted at runtime).
No "TBD"/"implement later"/"add error handling" hand-waving. All code blocks are
complete.

**3. Type / name consistency** — `Test-SyncStale` and `Write-SyncTimestamp` are
defined in Task 3 and consumed unchanged in Task 4. The state paths
`~/.gigapowers/` and `~/.gigapowers/last-sync` are identical across
`session-start.ps1`, `status.md`, and `sync.md`. The `brainstorming`-directory
check for "is superpowers in Codex" is identical in `init.md` and `status.md`.
Plugin name `gigapowers` and marketplace ref `gigapowers@gigapowers` are
consistent across `marketplace.json`, `plugin.json`, both READMEs, and Task 10.
