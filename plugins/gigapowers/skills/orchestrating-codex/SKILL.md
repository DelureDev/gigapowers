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
| Before "done" | Adversarial review of the diff | Stop-gate if enabled, else `codex exec` yourself |
| Stuck (2+ failed debug rounds) | Fresh-context diagnosis | `codex:codex-rescue` agent |

You decide the judgment-call rows. **Pre-completion adversarial review is your
responsibility either way.** The codex plugin's Stop-gate automates it *when
enabled* — but the gate is optional and may be off. Before declaring a
non-trivial task done, confirm a Codex adversarial pass actually happened: if
the Stop-gate is on it fired automatically (don't duplicate it); if it's off,
run one yourself with `codex exec`. Never skip the review on the assumption the
gate covered it.

## How to consult Codex (the part that matters)

A weak consult — "here's my code, looks good right?" — invites validation and
wastes the call. A strong consult gives Codex what it needs to *disagree well*:

1. **Context** — the goal, the constraints, what you already tried.
2. **The artifact** — the actual diff / plan / approach, not a summary of it.
3. **An adversarial ask** — "What's wrong with this? What breaks it? What would
   you have done differently?" Never "is this OK?"

Example:
```
codex exec "Reviewing a design decision. Goal: <...>. Constraints: <...>.
I'm leaning toward approach A: <...>. Approach B was: <...>.
What's wrong with A? What does B get right that A misses? Be specific and brief."
```

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
