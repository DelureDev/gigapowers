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
- Missing → the Codex-side install is a one-time interactive step (codex-cli has
  no non-interactive plugin install). Relay the install steps from
  `${CLAUDE_PLUGIN_ROOT}/references/codex-install.md` to the user and ask them to
  run them once, then continue — do not block the remaining steps on it.

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
