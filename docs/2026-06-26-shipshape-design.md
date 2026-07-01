# shipshape — design spec

**Date:** 2026-06-26
**Status:** Approved design, pre-implementation
**Owner:** yusheng
**Lives in:** `~/claw-skills/skills/shipshape/` (symlinked into `~/.claude/skills`, picked up by Codex)
**Also published as:** a public standalone `shipshape` GitHub repo for others to reuse

---

## 1. Summary

`shipshape` is a single skill that conducts a full-lifecycle, "no-slop" development flow:
from a project/change description, through planning, visual diagrams, build, review, a hard
pre-push quality gate, and a clean pull request — without reimplementing any of the existing
pieces. It is an **orchestrator**: it sequences existing skills and tools with checkpoints.

The hard quality gate is provided by [`no-mistakes`](https://github.com/kunchenguid/no-mistakes),
a local AI git proxy that runs a `rebase → review → test → docs → lint → push → PR → CI`
pipeline in a disposable worktree and only forwards a branch to the real remote once it passes.
`no-mistakes` is agent-agnostic (claude, codex, …) and agent-native (ships a `/no-mistakes`
skill driving a non-interactive `no-mistakes axi` TOON interface), so `shipshape` drives it
through that existing skill rather than re-encoding its logic.

Visual diagrams are produced with [`glimpse`](https://github.com/YushengAuggie/glimpse) — a live
HTML canvas driven over Chrome DevTools Protocol (`glimpse publish` / `glimpse ask`).

**Tagline alignment with no-mistakes:** *kill the slop, raise a clean PR* — with a visual
record of what changed.

## 2. Locked decisions

| Decision | Choice |
|----------|--------|
| Positioning vs existing review tooling | **Layered.** `/crew` + planning superpowers run during build; `no-mistakes` is the *final* hard gate before push/PR. |
| Diagram scope | **Plan-time architecture diagram + post-gate refresh.** Architecture diagram drawn at plan-time for design approval; after the gate, the architecture is re-synced and the change diagram is rendered from the final state. No separate pre-gate change diagram — the human only needs to read the truthful, post-fix diagram. |
| Skill scope | **Full-lifecycle orchestrator** that *conducts* existing skills (does not reimplement them). |
| Codex parity | **Full parity, verified first** — a Codex↔glimpse CDP spike gates the build. |
| PR shape | **One pipeline run → one PR, multiple commits allowed** (native `no-mistakes` behavior). Not gstack-style one-PR-per-commit stacks. |
| Post-gate diagrams | Diagrams **re-rendered from the final gated state** and pushed into the PR, because the gate can auto-fix code/docs. |

## 3. The pipeline (7 phases)

| # | Phase | Delegates to | Output / checkpoint |
|---|-------|--------------|---------------------|
| 0 | **Capture intent** | — | The project/change description is captured once and reused as both the brainstorm seed and the `--intent` string for `no-mistakes`. |
| 1 | **Plan** | `superpowers:brainstorming` → `writing-plans`, or `/autoplan` | Spec + implementation plan written to the repo's `docs/`. |
| 2 | **Architecture diagram** | `glimpse` (via `canvas`/`chrome-cdp` skills) | Mermaid → self-contained HTML, **pinned** to the canvas. `glimpse ask` blocks for a "design looks right?" approval. |
| 3 | **Build** | `superpowers:test-driven-development` / `subagent-driven-development` | Code committed on a feature branch. |
| 4 | **Crew review (early)** | `/crew` (CEO/eng/design/devex/security/QA reviewers) | Advisory, parallel. Findings fixed before the gate. **Scaled to diff size** — skippable for trivial changes with a note. |
| 5 | **Gate** | the installed `/no-mistakes` skill (drives `no-mistakes axi run --intent …`) | Its own `rebase→review→test→docs→lint→push→PR→CI` pipeline. `auto-fix` findings authorized; `ask-user` findings relayed to the user verbatim; loop until an `outcome:`. |
| 6 | **Post-gate diagram** | `glimpse` | Render diagrams from the **final gated state** (the gate may have auto-fixed code/docs): re-sync the architecture diagram and produce the change diagram. Publish to the canvas and push the artifacts into the no-mistakes PR (branch files + PR body) so the human reviews a truthful diagram and it stays on record. |
| 7 | **Summary / handoff** | — | Surface PR link, list any gate auto-fixes, link both diagrams. On `checks-passed`, ask the user to review/merge. |

### 3.1 Why two review passes (phase 4 + phase 5) is intentional
`/crew` is deep, parallel, advisory — it runs while build context is fresh and catches
design/architecture issues so the gate passes on the first try. `no-mistakes` is the
mechanical hard gate that guarantees nothing slips to the remote. They are complementary,
not redundant; phase 4 scales down (or skips) for small diffs to avoid double-paying.

### 3.2 Where testing happens

Testing of the **shipped change** occurs twice, by design:

- **Phase 3 (build)** authors tests alongside the code via TDD / subagent-driven development —
  tests are written *with* the feature, not after.
- **Phase 5 (gate)** re-runs them: `no-mistakes`'s pipeline executes regression + new tests in
  its disposable worktree and **will not forward the branch if tests fail** (it parks or fails
  the run). This is the enforcement layer — the author cannot self-certify.

So `shipshape` does not add a test runner; it relies on TDD producing the tests and the gate
enforcing them. Testing of **`shipshape` itself** (it is prose orchestration, not code) is
covered by the Codex↔glimpse spike (§6) plus the end-to-end dry-run on a real change (§10),
against the success criteria in §12.

## 4. Component boundaries

`shipshape` stays a **thin conductor**: each phase delegates to a skill/tool that remains
independently runnable exactly as it is today. The skill adds only sequencing, checkpoints,
intent threading, and the diagram lifecycle. Critically, phase 6 invokes the **upstream
`/no-mistakes` skill** instead of re-encoding `axi` driving logic, so `shipshape` inherits
`no-mistakes` updates automatically.

## 5. Diagram mechanics (glimpse)

- Diagrams are authored as **Mermaid source (`.mmd`) + rendered self-contained HTML**, kept
  side-by-side; the source is the editable truth, the HTML is what's published. This matches
  the existing "keep md + html in sync" habit.
- Publish: `glimpse publish <slug> "<title>" <file.html>`; pin the architecture diagram.
- Approval checkpoints: `glimpse ask <slug> "<title>" <file>` blocks until the user responds
  on the canvas.
- A small reusable **Mermaid→HTML template** ships inside the skill, shared by phases 2 and 6.
- Slugs are stable per change (e.g. `arch-<branch>`, `change-<branch>`) so the post-gate phase
  updates the same artifacts rather than creating duplicates.
- **Glimpse is optional (graceful degrade):** if glimpse/Chrome-CDP is unavailable, the skill
  still writes the self-contained HTML diagram to a file and tells the user to open it — the
  pipeline (gate + PR) never blocks on the canvas being up.

## 6. Cross-agent parity (Claude Code + Codex)

- The skill lives once in `~/claw-skills/skills/shipshape/` and is shared to both agents via the
  existing symlink setup; `no-mistakes init` installs `/no-mistakes` for both.
- `no-mistakes axi` output and commands are identical across agents — no per-agent branching for
  the gate.
- **Verification spike (blocking):** before building the skill, confirm a Codex session can drive
  glimpse over CDP to `localhost:4321` (publish a test artifact). If it cannot, stop and decide
  (graceful-degrade vs claude-only diagrams) before proceeding — no wasted work.
- Skill prose uses tool-name-agnostic language per claw-skills/Codex conventions.

## 7. Preconditions & configuration

`no-mistakes` requires: work committed, on a **feature branch** (not default), repo `init`'d.
`shipshape` checks and sets these up front so the gate never errors on entry. Per-repo config
lives in `.no-mistakes.yaml` (e.g. `auto_fix.review: 0` keeps review findings parked for a
decision). Installation: `no-mistakes` via its `install.sh`; `no-mistakes init` per repo
(`--fork-url` for forks).

## 8. PR / multi-commit handling

One `shipshape` run gates one branch — which may contain **multiple commits** — into a single
reviewable PR (native `no-mistakes` behavior; it validates the branch's committed history).
This supports reviewing a few related commits together. It does **not** create gstack-style
one-PR-per-commit stacks; that workflow stays on `gstack`.

## 9. Distribution & self-contained install

**Requirement:** a public reuser runs **one install** and can use the skill — no separate
dependency hunt. Achieved by tiering dependencies and shipping a single install script (the
`no-mistakes` `curl … | sh` model).

### 9.1 Dependency tiers

| Tier | What | How the reuser gets it |
|------|------|------------------------|
| **Required** | `no-mistakes` (the gate — the whole point) | The repo's one-line `install.sh` installs the skill **and** installs `no-mistakes` if missing. |
| **Bundled** (no separate install) | the `shipshape` SKILL.md, the Mermaid→HTML diagram template, lightweight reviewer prompts | Shipped *inside* the repo; arrive with the one download. |
| **Optional, graceful-degrade** | `glimpse` (canvas) | If present, diagrams render live; if absent, the skill writes the HTML to a file and the gate/PR proceed anyway. Install script offers to add it. |
| **Optional, enhance-if-present** | the author's richer skills (`/crew`, `superpowers` planning) | Used automatically *if installed*; otherwise `shipshape` falls back to its bundled lightweight plan + relies on `no-mistakes`'s own built-in AI review. Never a hard requirement. |

**Key point:** the only hard dependency is `no-mistakes`, and the install script handles it.
`no-mistakes` already performs AI review/test/docs/lint in its gate, so the public skill is
fully functional with just that — crew and superpowers are upgrades, not prerequisites. This
keeps "one install, then use it" honest.

### 9.2 Two distribution targets

1. **Develop in `~/claw-skills`** (`YushengAuggie/claw-skills`, `main`) so it is immediately live
   in Claude Code + Codex. Commit + push when done. (This private copy may freely use the
   author's own `/crew` and `superpowers` skills.)
2. **Publish a public standalone `shipshape` repo** on GitHub with the bundled assets + a single
   `install.sh`, mirroring how `no-mistakes`/superpowers are distributed. The public copy uses
   the dependency tiers in §9.1 so it works from one install.

## 10. Build order / milestones

1. Install `no-mistakes`; drive a throwaway change through the native `/no-mistakes` to learn the
   real `axi` TOON output and gate behavior.
2. Codex↔glimpse CDP verification spike (blocking gate).
3. Write `~/claw-skills/skills/shipshape/SKILL.md` + the Mermaid→HTML diagram helper, conducting
   the 7 phases.
4. Dry-run end-to-end on a small real change in one repo.
5. Commit to claw-skills + push.
6. Build the public `shipshape` repo: bundle assets + a single `install.sh` (per §9), and
   **verify a clean one-install on a machine without the author's skills** — confirming the
   degrade/enhance tiers behave.

## 11. Non-goals (YAGNI)

- No reimplementation of planning, review, gate, or canvas logic — delegate only.
- No gstack-style stacked multi-PR support.
- No custom gate pipeline; use `no-mistakes`'s pipeline and `.no-mistakes.yaml` config.
- No always-on heavy crew review for trivial diffs.

## 12. Success criteria

- A single `shipshape` invocation takes a described change to a clean, gated PR with up-to-date
  architecture + change diagrams visible in the PR.
- Works identically from Claude Code and Codex.
- Each underlying skill remains usable on its own.
- The skill is published publicly and usable after **one install**, with `no-mistakes` as the
  only hard dependency and everything else bundled or gracefully optional.
