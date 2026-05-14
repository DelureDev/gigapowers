# Gigapowers — Design Spec

**Date:** 2026-05-14
**Status:** Approved (design locked, Approach A)
**Repo:** `github.com/DelureDev/gigapowers`

---

## 1. Purpose

Gigapowers is a user-scope **Claude Code plugin** that makes Claude and Codex
build software as **peers** on every project. Claude is always the orchestrator;
Codex is *structurally* always in the loop — never an afterthought, never
forgotten.

It sits **on top of** two existing things and reimplements neither:

- **superpowers** — installed in *both* stacks (Claude Code + Codex CLI).
- **`codex@openai-codex`** — the existing Claude Code plugin that already
  provides Codex machinery (rescue agent, adversarial review, stop-gate hook).

Gigapowers is the thin layer that (a) bootstraps both stacks per project,
(b) keeps both superpowers installs current, and (c) carries the
"when and how does Claude consult Codex" brain.

## 2. Goals

1. **One-command project bootstrap** — `/gigapowers:init` makes a fresh project
   have Claude+superpowers *and* Codex+superpowers ready, plus the project's
   `AGENTS.md` / `CLAUDE.md` / `.codex/config.toml` scaffolded.
2. **Both superpowers installs stay current** — Claude side is already handled
   by Claude Code's native plugin auto-update; Codex side is bridged by a
   throttled gigapowers SessionStart hook.
3. **Codex is a peer at every lifecycle stage** — design, planning,
   implementation, pre-completion, and stuck-debugging — with a **hook-enforced
   gate** guaranteeing the pre-completion adversarial review is never skipped.

## 3. Non-Goals

- **Not a fork of superpowers.** Gigapowers consumes superpowers; it does not
  copy or modify its skills.
- **Not a reimplementation of the codex plugin.** Rescue, adversarial review,
  and the stop-gate already exist in `codex@openai-codex`; gigapowers delegates
  to them.
- **Codex is never the orchestrator.** Claude always drives. (Decided during
  brainstorming.)
- **Not cross-platform-first.** Windows is the primary target environment.
  Hooks are written portably only where that is cheap.

## 4. Key Constraints Discovered During Brainstorming

These shaped the design and must be respected by the implementation:

| Constraint | Implication |
|---|---|
| Claude **cannot type `/codex:*` slash commands** — they are user-only. | Gigapowers builds on the codex plugin surfaces Claude *can* invoke: the `codex:codex-rescue` **agent** (via the Agent tool), the `codex:rescue` / `codex:setup` **skills**, the plugin's **hooks**, and **`codex exec`** via the shell. |
| Claude Code **already auto-updates** marketplace plugins (`autoUpdatesChannel: latest`). | Gigapowers does **nothing** for the Claude-side superpowers update. Proven: superpowers `installedAt 2026-03-19` but `lastUpdated 2026-05-07`. |
| Codex CLI (0.130.0) has `codex plugin marketplace add/upgrade/remove` but **no startup auto-update**. | Gigapowers' SessionStart hook runs `codex plugin marketplace upgrade`, throttled. |
| superpowers in Codex is **not installed yet** (`~/.codex/skills/` has only built-ins). | `/gigapowers:init` installs it the first time. superpowers ships a `.codex-plugin/` and publishes to a Codex marketplace; the exact `marketplace add` target is resolved in implementation. |
| superpowers ships `using-superpowers/references/codex-tools.md` mapping its Claude-tool vocabulary to Codex equivalents. | Codex can run superpowers skills natively; no translation layer needed in gigapowers. |
| The codex plugin **already ships a Stop-hook review gate** (`stop-review-gate.md` + `hooks.json`). | Gigapowers does **not** add its own Stop hook. It ensures that gate is enabled (via `codex:setup`) rather than duplicating it. |

## 5. Distribution & Repo Layout

New repo `github.com/DelureDev/gigapowers`, structured as a Claude Code plugin
**marketplace** (same pattern as `openai/codex-plugin-cc`):

```
gigapowers/                          # repo root = the marketplace
  .claude-plugin/
    marketplace.json                 # lists the gigapowers plugin
  plugins/
    gigapowers/                      # the plugin itself
      .claude-plugin/
        plugin.json                  # name, version, description, author
      commands/
        init.md                      # /gigapowers:init
        status.md                    # /gigapowers:status
        sync.md                      # /gigapowers:sync
      skills/
        orchestrating-codex/
          SKILL.md                   # THE BRAIN
      hooks/
        hooks.json                   # SessionStart registration
        session-start.ps1            # throttled Codex-side updater + readiness check
      templates/
        AGENTS.md                    # project source-of-truth template
        CLAUDE.md                    # @AGENTS.md + Claude-specific delta template
        codex-config.toml            # project .codex/config.toml template
      README.md
  docs/
    superpowers/
      specs/2026-05-14-gigapowers-design.md
      plans/                         # implementation plan lands here
  README.md                          # marketplace-level readme
  LICENSE
```

Install path for the user:
```
claude plugin marketplace add DelureDev/gigapowers
claude plugin install gigapowers@gigapowers
```

## 6. Components

### 6.1 `orchestrating-codex` skill — the brain

A flexible (judgment-based) skill Claude invokes at lifecycle decision points.
It frames Codex as a **peer collaborator with alternative opinions**, not a
review gate. Contents:

- **Lifecycle touchpoint map** — when Codex gets pulled in:

  | Stage | Codex's role | Trigger |
  |---|---|---|
  | Design / brainstorm | Second opinion when ≥2 viable approaches exist | Skill judgment |
  | Planning | Review the plan for gaps / missed edge cases before execution | Skill judgment |
  | Implementation | Parallel batch work; second opinion on a tricky unit | Skill judgment |
  | Before declaring "done" (non-trivial work) | Adversarial diff review | **Hook-enforced** (codex plugin's stop gate) |
  | Stuck debugging (2+ failed rounds) | Fresh-context diagnosis | Skill judgment |

- **How to consult Codex** — give full context, explicitly ask for
  *disagreement and blind spots* (not validation), and how to reconcile:
  fix clear wins, surface judgment calls to the user as
  "Codex flagged X — fix? skip?".
- **Invocation mechanics** — dispatch the `codex:codex-rescue` agent for
  substantial tasks / diagnosis; use `codex exec "..."` for lightweight inline
  consults; never type `/codex:*` (user-only).
- **"Don't call Codex for"** — trivial edits, doc-only changes, when the user
  said skip, recursively. (Formalizes the loose prose in the user's global
  `CLAUDE.md`.)

### 6.2 `/gigapowers:init` command — per-project bootstrap

Run in a project root. Steps, each idempotent and each reporting what it did:

1. Verify Claude-side superpowers present (user scope) — report version.
2. Verify Codex-side superpowers: if `~/.codex/skills/` lacks superpowers
   skills, install via `codex plugin marketplace add` + install (exact target
   resolved in implementation).
3. Write project `AGENTS.md` from template if absent (or with `--force`).
4. Write project `CLAUDE.md` (= `@AGENTS.md` + Claude delta) from template if absent.
5. Write `.codex/config.toml` from template if absent.
6. Ensure git is initialized.
7. Ensure the codex plugin's stop-review gate is enabled (delegates to
   `codex:setup`).
8. Print a summary of every action taken / skipped.

### 6.3 `/gigapowers:status` command

Read-only health check: Claude-side superpowers version, Codex-side superpowers
status, `codex` CLI version + auth state, last auto-update timestamp, whether
the stop gate is enabled.

### 6.4 `/gigapowers:sync` command

Manual escape hatch: force `codex plugin marketplace upgrade` now, refresh the
throttle timestamp, report before/after versions.

### 6.5 Hooks

- **`hooks.json`** registers a **SessionStart** hook → `session-start.ps1`.
- **`session-start.ps1`**:
  - Reads a throttle timestamp (`~/.gigapowers/last-sync`). If <24h old, exit
    immediately (zero-cost session start).
  - If stale (or missing): run `codex plugin marketplace upgrade` **non-blocking**,
    write a fresh timestamp.
  - Lightweight readiness check: is `codex` installed and authed? Emit a short
    notice if not. Never blocks or fails the session.
- **No Stop hook** — gigapowers relies on the codex plugin's existing stop gate.

### 6.6 Templates

`AGENTS.md`, `CLAUDE.md`, `codex-config.toml` — derived from Section 2 of the
user's `cc-codex-playbook` README. `CLAUDE.md` is strictly `@AGENTS.md` + a
Claude-specific delta (no duplication — single source of truth in `AGENTS.md`).

## 7. Data Flow

```
Session start
  └─> SessionStart hook → throttle check → (stale?) codex marketplace upgrade (bg)

New project
  └─> user runs /gigapowers:init → both stacks verified + project files scaffolded

During work
  └─> Claude invokes orchestrating-codex skill at lifecycle decision points
        └─> consults Codex via codex-rescue agent or `codex exec`

Before "done" (non-trivial)
  └─> codex plugin's Stop gate → Codex adversarial review (enforced)
```

## 8. Error Handling

| Situation | Behavior |
|---|---|
| `gh` not on PATH | Detected; use full path. (Not gigapowers' concern at runtime — relevant only to its own dev/CI.) |
| `codex` not installed | `init` / `status` report it clearly; auto-update hook no-ops gracefully. |
| `codex` not authed | Reported by `init` / `status`; auto-update skipped, not fatal. |
| Offline at session start | `codex marketplace upgrade` fails silently, logged; retried next stale window. |
| Throttle file missing/corrupt | Treated as stale → sync runs. |
| superpowers already current | Upgrade is a fast no-op; throttle still advances. |

## 9. Testing Strategy

- **Plugin loads** — install locally, confirm `/gigapowers:*` commands appear,
  `orchestrating-codex` skill is invocable, SessionStart hook registers.
- **`/gigapowers:init`** — run in a scratch directory, assert each file is
  created with correct content; re-run to confirm idempotency.
- **Throttle logic** — unit-test the timestamp staleness comparison in
  `session-start.ps1` (fresh / stale / missing / corrupt).
- **Codex superpowers install** — verify the `marketplace add` path against a
  clean `~/.codex/skills/` check.
- **Adversarial review** — Codex reviews the final diff before merge
  (dogfooding the very workflow gigapowers exists to enforce).

## 10. Open Questions / Risks

- **Exact Codex superpowers install incantation.** superpowers ships
  `.codex-plugin/` and a sync script targeting `prime-radiant-inc/openai-codex-plugins`.
  The precise `codex plugin marketplace add` target is resolved during
  implementation by inspecting that marketplace.
- **Codex CLI plugin behavior may shift across versions** — pin observed
  behavior to 0.130.0 in code comments; `/gigapowers:status` surfaces drift.
- **Windows-first** — `session-start.ps1` is PowerShell; a bash fallback is a
  nice-to-have, not a v1 requirement.
