# Correct Codex-side Superpowers Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken `~/.codex/skills/brainstorming` detection check with a three-state recipe that reflects how Codex 0.130.0 actually stores and gates plugins.

**Architecture:** A single detection recipe lives in `references/codex-install.md`; `commands/init.md` and `commands/status.md` reference it instead of restating their own check. These are markdown instruction files — there are no automated unit tests, so each task verifies with `grep` assertions plus, for the recipe itself, a run against the live system.

**Tech Stack:** Markdown (Claude Code plugin reference doc + slash-command files), PowerShell snippets, git.

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `references/codex-install.md` | Canonical Codex-side reference — owns the detection recipe and the one-time install steps | Modify |
| `commands/init.md` | `/gigapowers:init` — references the recipe, auto-enables when disabled | Modify |
| `commands/status.md` | `/gigapowers:status` — references the recipe, read-only reporting | Modify |

All paths are relative to the plugin root `C:\Pyth\gigapowers\plugins\gigapowers\`.
Work happens on the existing branch `fix/codex-superpowers-detection`.

Task 1 must land first — it creates the recipe that Tasks 2 and 3 reference.

---

## Task 1: Rewrite the detection recipe in `codex-install.md`

**Files:**
- Modify: `references/codex-install.md` (lines 12-22 "Check if already installed"; install steps ~33-37; follow-up line ~39)

- [ ] **Step 1: Confirm the broken check is present (baseline)**

Run: `grep -n "skills.brainstorming\|skills\\\\brainstorming" references/codex-install.md`
Expected: matches on the old `~/.codex/skills/brainstorming` path (lines ~14, ~18, ~39).

- [ ] **Step 2: Replace the "Check if already installed" section**

Replace this exact block:

```markdown
## Check if already installed

Superpowers is live in Codex when `~/.codex/skills/` contains a `brainstorming`
directory:

```powershell
Test-Path "$HOME\.codex\skills\brainstorming"
```

`True` → superpowers is installed, nothing to do. `False` → run the one-time
install below.
```

with:

```markdown
## Check if already installed

Codex 0.130.0 keeps *plugin*-provided skills in the plugin cache, not in
`~/.codex/skills/` (that directory holds only Codex's built-in skills). A plugin
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

The marketplace segment (normally `openai-curated`) and the content-hash segment
are wildcards — this also covers superpowers added via a user Git marketplace.

**Enabled?** Read `~/.codex/config.toml`. Find a table whose key starts with
`[plugins."superpowers@`. An absent entry or `enabled = true` means enabled; an
explicit `enabled = false` means disabled:

```powershell
Select-String -Path "$HOME\.codex\config.toml" -Pattern '^\s*\[plugins\."superpowers@' -Context 0,2
```

If that block shows `enabled = false`, set it to `enabled = true` and restart
Codex. Combine the two checks: installed + not-disabled → **ready**; installed +
disabled → **installed-but-disabled**; not installed → **not-installed**.
```

- [ ] **Step 3: Add an "ensure enabled" step to the install steps**

Replace this exact block:

```markdown
1. Open Codex: `codex`
2. In the TUI, open the plugin browser: `/plugins`
3. Search for: `superpowers`
4. Select **Install Plugin**.
5. Quit and reopen Codex.
```

with:

```markdown
1. Open Codex: `codex`
2. In the TUI, open the plugin browser: `/plugins`
3. Search for: `superpowers`
4. Select **Install Plugin**.
5. Ensure the plugin is **enabled** — the TUI may leave a freshly installed
   plugin `enabled = false`. Toggle it on, or set `enabled = true` under
   `[plugins."superpowers@openai-curated"]` in `~/.codex/config.toml`.
6. Quit and reopen Codex.
```

- [ ] **Step 4: Fix the follow-up confirmation line**

Replace this exact line:

```markdown
Then re-run the check above to confirm `~/.codex/skills/brainstorming` exists.
```

with:

```markdown
Then re-run the detection above to confirm the state is **ready**.
```

- [ ] **Step 5: Verify the old path is gone and the new recipe is present**

Run: `grep -rn "skills.brainstorming\|skills\\\\brainstorming" references/codex-install.md`
Expected: no matches.

Run: `grep -n "plugins.cache.*superpowers" references/codex-install.md`
Expected: matches the new cache-dir glob.

- [ ] **Step 6: Verify the recipe against the live system**

Run: `powershell -NoProfile -Command "Get-ChildItem \"$HOME\.codex\plugins\cache\*\superpowers\*\skills\brainstorming\" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName"`
Expected: prints a path ending in `...\superpowers\<hash>\skills\brainstorming` (installed).

Run: `powershell -NoProfile -Command "Select-String -Path \"$HOME\.codex\config.toml\" -Pattern '^\s*\[plugins\.\"superpowers@' -Context 0,2"`
Expected: shows the `[plugins."superpowers@openai-curated"]` table with `enabled = true` (not disabled).
Combined → state is **ready**, confirming the recipe resolves correctly.

- [ ] **Step 7: Commit**

```bash
git add references/codex-install.md
git commit -m "fix: correct Codex-side superpowers detection recipe

Codex 0.130.0 keeps plugin skills in the plugin cache, not
~/.codex/skills/, and gates them via a config.toml enabled flag.
Replace the single Test-Path check with a three-state recipe (ready /
installed-but-disabled / not-installed) and add an explicit enable step
to the install instructions.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Point `init.md` step 2 at the recipe and allow auto-enable

**Files:**
- Modify: `commands/init.md` (frontmatter line 4 `allowed-tools`; step 2, lines 20-26)

- [ ] **Step 1: Confirm the broken check is present (baseline)**

Run: `grep -n "skills.*brainstorming" commands/init.md`
Expected: one match on the old `~/.codex/skills/` check in step 2.

- [ ] **Step 2: Add `Edit` to `allowed-tools`**

Replace this exact line:

```markdown
allowed-tools: Bash, Read, Write, Skill, AskUserQuestion
```

with:

```markdown
allowed-tools: Bash, Read, Write, Edit, Skill, AskUserQuestion
```

- [ ] **Step 3: Rewrite step 2**

Replace this exact block:

```markdown
## 2. Verify Codex-side superpowers
Check whether `~/.codex/skills/` contains a `brainstorming` directory.
- Present → report OK.
- Missing → the Codex-side install is a one-time interactive step (codex-cli has
  no non-interactive plugin install). Relay the install steps from
  `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md` to the user and ask them to
  run them once, then continue — do not block the remaining steps on it.
```

with:

```markdown
## 2. Verify Codex-side superpowers
Detect Codex-side superpowers using the recipe in
`${CLAUDE_PLUGIN_ROOT}/references/codex-install.md` ("Check if already
installed"). Act on the resulting state:
- **ready** → report OK.
- **installed-but-disabled** → set `enabled = true` for the superpowers plugin
  table in `~/.codex/config.toml`, then tell the user to restart Codex for it to
  take effect. Report as fixed.
- **not-installed** → the Codex-side install is a one-time interactive step
  (codex-cli has no non-interactive plugin install). Relay the install steps
  from that same file to the user and ask them to run them once, then continue —
  do not block the remaining steps on it.
```

- [ ] **Step 4: Verify the change**

Run: `grep -n "skills.*brainstorming" commands/init.md`
Expected: no matches.

Run: `grep -n "allowed-tools:" commands/init.md`
Expected: line includes `Edit`.

Run: `grep -n "installed-but-disabled" commands/init.md`
Expected: one match in step 2.

- [ ] **Step 5: Commit**

```bash
git add commands/init.md
git commit -m "fix: point /gigapowers:init at the corrected Codex detection recipe

Step 2 now references the three-state recipe in codex-install.md and
auto-enables superpowers when it is installed but disabled. Add Edit to
allowed-tools for the targeted config.toml change.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Point `status.md` step 2 at the recipe

**Files:**
- Modify: `commands/status.md` (step 2, lines 8-9)

- [ ] **Step 1: Confirm the broken check is present (baseline)**

Run: `grep -n "skills.*brainstorming" commands/status.md`
Expected: one match on the old `~/.codex/skills/` check in item 2.

- [ ] **Step 2: Rewrite step 2**

Replace this exact block:

```markdown
2. **Codex-side superpowers** — check `~/.codex/skills/` for a `brainstorming`
   directory; report present or absent.
```

with:

```markdown
2. **Codex-side superpowers** — detect using the recipe in
   `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md` ("Check if already
   installed"); report one of **ready**, **installed but disabled** (add the
   note "run /gigapowers:init to enable"), or **not installed**. This command is
   read-only — report state, do not edit `config.toml`.
```

- [ ] **Step 3: Verify the change**

Run: `grep -n "skills.*brainstorming" commands/status.md`
Expected: no matches.

Run: `grep -n "installed but disabled" commands/status.md`
Expected: one match in item 2.

- [ ] **Step 4: Confirm `allowed-tools` is unchanged**

Run: `grep -n "allowed-tools:" commands/status.md`
Expected: still `allowed-tools: Bash, Read` — status.md stays read-only, no `Edit`.

- [ ] **Step 5: Commit**

```bash
git add commands/status.md
git commit -m "fix: point /gigapowers:status at the corrected Codex detection recipe

Item 2 now references the three-state recipe in codex-install.md and
reports ready / installed-but-disabled / not-installed. Stays read-only.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] **Step 1: No stale path references remain in shipped files**

Run: `grep -rn "codex.skills.brainstorming\|skills\\\\brainstorming" references/ commands/ hooks/`
Expected: no matches anywhere in shipped files (docs/ planning records are intentionally out of scope).

- [ ] **Step 2: All three files reference the canonical recipe**

Run: `grep -rln "codex-install.md" commands/init.md commands/status.md`
Expected: both files match.

- [ ] **Step 3: Confirm clean git state**

Run: `git status --short`
Expected: clean — all three changes committed on `fix/codex-superpowers-detection`.

---

## Self-Review

**1. Spec coverage:**
- Three-state recipe → Task 1, Step 2. ✓
- Cache-dir glob with wildcard marketplace/hash segments → Task 1, Step 2. ✓
- `config.toml` enabled-flag check → Task 1, Step 2. ✓
- Drop `~/.codex/skills/` path → Task 1 (Steps 2-4), verified Steps 5 + Final. ✓
- `codex-install.md` install steps gain an "ensure enabled" step → Task 1, Step 3. ✓
- `codex-install.md` follow-up confirmation line fixed → Task 1, Step 4. ✓
- `init.md` step 2 references recipe + handles three states + auto-enables → Task 2, Step 3. ✓
- `init.md` gains `Edit` in `allowed-tools` → Task 2, Step 2. ✓
- `status.md` step 2 references recipe + reports three states, stays read-only → Task 3, Steps 2 + 4. ✓
- Out of scope (docs/ planning records, session-start hook, no new script) → respected; Final Step 1 scopes the grep to shipped dirs. ✓
- Verification is manual (grep + live recipe run) → every task, plus Task 1 Step 6 runs the recipe against the live system. ✓

No gaps.

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/vague steps. Every edit step shows the exact old and new text. ✓

**3. Type consistency:** State names are consistent across all tasks — **ready**, **installed-but-disabled** (hyphenated in recipe/init prose; "installed but disabled" as the status.md user-facing label is intentional and called out in Task 3), **not-installed**. The cache-dir glob string is identical in Task 1 Step 2 and Task 1 Step 6. The `allowed-tools` line is quoted identically in Task 2 Step 2. ✓
