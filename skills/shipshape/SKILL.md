---
name: shipshape
description: Full-lifecycle no-slop development flow — drive a change from intent through plan, architecture diagram, build, review, a hard pre-push quality gate (no-mistakes), and a clean PR with up-to-date diagrams. Use when the user says "shipshape this", "/shipshape", "take this to a clean PR", "run the full pipeline", "ship this change properly", or otherwise wants a change driven end-to-end to a reviewed, gated pull request. Conducts existing skills (planning, /crew, glimpse canvas, /no-mistakes). Only hard dependency is no-mistakes; glimpse and /crew are used if present.
---

# shipshape — full-lifecycle no-slop development flow

## What this is

One command that drives a change from a plain-English intent all the way to a clean,
reviewed, gated pull request — with up-to-date diagrams. It **conducts existing skills**;
it does not reimplement planning, review, the gate, or the canvas. The hard quality gate is
the `no-mistakes` tool (a local AI git proxy that runs review→test→docs→lint→push→PR→CI in a
disposable worktree and only forwards a clean branch).

## When to use it

Use when the user wants a change taken end-to-end: "shipshape this", "/shipshape <task>",
"take this to a clean PR", "ship this properly". `/shipshape <task>` does the work first then
gates it; bare `/shipshape` gates already-committed work on the current branch.

## Dependencies & degradation

Detect these once at the start and announce which tier you're running in.

- **Required — `no-mistakes`:** if `command -v no-mistakes` fails, stop and tell the user to
  install it (`curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh`,
  or shipshape's own `install.sh`).
- **Optional — glimpse (canvas):** if `glimpse doctor` is unhealthy, diagrams are written to a
  file by the render script (it falls back automatically). Never block the pipeline on the canvas.
- **Enhance — /crew + superpowers planning:** use them **if available**; otherwise use the
  bundled `assets/review-lenses.md` for review and a short inline plan, and rely on the
  `no-mistakes` gate's own AI review.

The bundled diagram script lives in this skill's own `assets/` directory — i.e. the base
directory reported when this skill loaded (`<skill-dir>/assets/render-diagram.sh`). Always
invoke it by that path; never hardcode an absolute user path.

## The 7 phases

Create a TodoWrite item per phase. Thread the captured intent (Phase 0) through to Phase 5.

### Phase 0 — Capture intent
Capture, in one place, what the user set out to accomplish: the objective, key decisions,
tradeoffs, and constraints — not a description of the diff. Reuse this verbatim as the
brainstorm seed and later as the `no-mistakes` intent.

### Phase 1 — Plan
If `superpowers:brainstorming` / `writing-plans` (or `/autoplan`) are available, invoke them to
produce a spec + plan. Otherwise write a short inline plan (goal, files, steps, tests). Confirm
the plan with the user before building.

### Phase 2 — Architecture diagram (approval checkpoint)
Write a Mermaid flowchart of the target design to a `.mmd` file (keep this source in the repo —
it is the editable truth). Render and pin it:

```
<skill-dir>/assets/render-diagram.sh arch-<branch> "Architecture: <title>" <file.mmd> --pin
```

If glimpse is up, ask for approval on the canvas (`glimpse ask`) or in chat. If the user wants
changes, return to Phase 1.

### Phase 3 — Build
Implement per the plan. Prefer `superpowers:test-driven-development` /
`subagent-driven-development` if available — **write tests with the code**. Commit on a feature
branch (never the default branch). Multiple commits are fine; they become one PR.

### Phase 4 — Crew review (early, optional, scaled)
For non-trivial diffs, invoke `/crew` if available; else apply the lenses in
`<skill-dir>/assets/review-lenses.md` inline. Fix clear issues; surface judgment calls to the
user. Skip with a one-line note for trivial diffs.

### Phase 5 — Gate (no-mistakes)
Ensure preconditions, setting them up **automatically — never make the user run setup by hand**:
work committed; on a **feature branch** (not the default branch — create one if needed); and the
repo gated. To check the gate: if `git remote` has no `no-mistakes` remote, run `no-mistakes init`
yourself first (it is non-interactive and uses `origin`). Then **invoke the installed
`no-mistakes` skill** (`/no-mistakes`) with the Phase 0 intent — it owns the correct sequence
(it pushes the branch through the gate remote, then drives `no-mistakes axi run --intent …`).
Do **not** re-encode that logic here.

**Make the gate reliable (part of setup):**
- **Deterministic commands.** If the repo has no `.no-mistakes.yaml`, add one with
  `commands.test` / `commands.lint` so those steps run real commands instead of a nested AI
  agent — faster, and it avoids agent kills under sandboxed execution. Detect the repo's real
  commands (npm/pnpm scripts, Makefile targets, `cargo test`, etc.); if none fit, use a
  lightweight validity check. (no-mistakes reads `commands.test` / `lint` / `format` from
  `.no-mistakes.yaml`, run via `sh -c`.)
- **No CI → trust the `axi run` return, not `axi status`.** `axi run --skip ci` does **not**
  work (the pipeline is started by the push, so the run's step plan is already fixed). You don't
  need it: for a repo with no CI, "no failing checks" counts as green, so the driving `axi run`
  (and the `/no-mistakes` skill) **returns `outcome: checks-passed`** once the PR is opened —
  that is terminal success (Phase 7). Do **not** judge success by polling `no-mistakes axi
  status`: it keeps the background CI monitor at `ci: running` with no `outcome:` line even after
  `checks-passed` was returned. The lingering monitor is harmless; `no-mistakes axi abort` tidies
  it if you want.
- **Transient agent blips.** The `review` and `document` steps always use the AI agent. A
  `signal: killed` / `daemon shutting down` on those is usually an environment hiccup — rerun
  once before treating it as a real failure.

- Relay every `ask-user` finding to the user **verbatim** (id, file, description); translate
  their decision into the gate's approve / fix / skip response. Let `auto-fix` findings apply.
- Loop until an `outcome:`. On `failed` / `cancelled`, fix on the same branch and rerun.
- If you ever need the raw interface details, see `<skill-dir>/reference/no-mistakes-axi.md`.
  Note from that reference: a bare `axi run` does **not** start a pipeline — a push through the
  gate remote starts it. The `/no-mistakes` skill handles this; only relevant if you bypass it.

### Phase 6 — Post-gate diagram
The gate may have changed code/docs (auto-fixes). Regenerate from the **final** state: re-render
the architecture diagram with the same `arch-<branch>` slug (so it updates in place) and render a
change diagram `change-<branch>` showing what this PR touches. Add both the `.mmd` source and the
rendered `.html` to the branch and reference them in the PR body, so the PR shows truthful,
current diagrams and they stay on record.

### Phase 7 — Summary / handoff
Print the PR link, list any gate auto-fixes (the gate reports a `fixes` table when it applied
any), and link both diagrams. On `checks-passed`, ask the user to review/merge — the gate opened
the PR but did not merge it.

## Cross-agent notes (Claude Code + Codex)

`no-mistakes axi` and `glimpse` commands are identical across agents, and this skill ships once
and is shared to both. Use plain shell commands and skill invocations — no agent-specific tool
names.

Codex driving the glimpse canvas over CDP is **verified** (see
`<skill-dir>/reference/codex-glimpse-spike.md`). In normal use, shipshape runs from inside the
target git repo, so Codex's standard sandbox is sufficient — `glimpse` and `no-mistakes` run as
ordinary commands. (The spike only needed a sandbox/trusted-dir override because it ran from a
non-repo scratch directory; that does not apply when shipping a real repo.)
