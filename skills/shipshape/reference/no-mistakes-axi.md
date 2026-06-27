# `no-mistakes axi` reference (captured behavior)

Reference doc for the `shipshape` skill. Everything below was captured from a
real `no-mistakes` run on a throwaway repo, not recalled from memory. Where a
shape could not be triggered live, it is marked **(from binary strings / help,
not observed live)**.

- **Tool:** `no-mistakes` — a Go CLI; local git proxy / quality gate.
- **Version captured:** `no-mistakes version v1.30.1 (59dfa25) 2026-06-21T22:28:43Z`
- **Installed:** binary at `~/.no-mistakes/bin/no-mistakes`, symlinked to
  `~/.local/bin/no-mistakes` (which was already on PATH). Installer
  (`docs/install.sh`) downloads the matching GitHub release tarball and runs
  `daemon restart` at the end. A background **daemon** (state in
  `~/.no-mistakes/`, sqlite at `~/.no-mistakes/state.sqlite`) drives all runs.
- **Platform of capture:** macOS arm64 (darwin/arm64), zsh.

## TOON output convention

`axi` prints token-efficient TOON to **stdout**; human progress goes to
**stderr**. Errors are also printed to stdout as `error: "..."`. Shapes:

- `key: value` scalars.
- `name[N]{col,col,...}:` then N indented comma-separated rows = a table.
- `help[N]: a,b,c` = N comma-separated agent hints (the next commands to run).

## How a run actually starts (important gotcha)

`no-mistakes axi run` does **not** create a pipeline from nothing. It *drives an
existing* run (internally it calls the daemon `rerun`). On a branch with no
prior run it fails:

```
error: "no run started for \"probe-change\": no previous run for branch probe-change"
```
(exit code 1)

A pipeline is **started by pushing through the gate remote**:
`git push no-mistakes <branch>`. The push hook prints `* Pipeline started` and
the daemon begins the pipeline. After that, `axi run --intent "..."` /
`axi status` / `axi respond` attach to and drive it. The push only fires the
hook on a genuine ref update (a no-op "Everything up-to-date" push does **not**
start a run).

> For the shipshape skill: the trigger is `git push no-mistakes <branch>`, then
> `no-mistakes axi run --intent "..."` to drive. `--intent` is required to
> start/drive a run.

## Subcommands (all confirmed via `--help`)

`no-mistakes axi [run | status | respond | logs | abort]`. Running `axi` with no
subcommand prints current state (same as a light `status`).

### `axi run`
Triggers/drives the pipeline for the current branch; blocks until the first
approval gate, a CI-ready point, or the final outcome.
```
--intent string   what the user set out to accomplish (REQUIRED to start a run)
--skip string     comma-separated pipeline steps to skip
-y, --yes         auto-resolve every gate (fix findings, then accept) until a decision point or outcome
```

### `axi respond`
Answers the gate currently awaiting approval, then blocks until the next gate /
CI-ready point / outcome.
```
--action string         approve | fix | skip   (REQUIRED)
--findings string       comma-separated finding IDs to fix (with --action fix)
--add-finding string    JSON finding object to add and fix (with --action fix)
--instructions string   guidance applied to selected findings (with --action fix)
--step string           step to respond to (default: the step awaiting approval)
-y, --yes               auto-resolve every subsequent gate until a decision point or outcome
```

### `axi status`
`--run string` — inspect a specific run ID (default: active or most recent).

### `axi logs`
```
--full          show the entire log instead of the tail
--run string    run ID (default: active or most recent)
--step string   step name (REQUIRED): intent, rebase, review, test, document, lint, push, pr, ci
```

### `axi abort`
No flags. Cancels the active run.

## The pipeline: 9 steps

Every run has a fixed `steps[9]` table. Step names (also the valid `--step`
values for `axi logs`):

`intent, rebase, review, test, document, lint, push, pr, ci`

Per-step **status** values observed: `skipped`, `pending`, `running`,
`awaiting_approval`, `completed`, `failed`, `fixing` (seen on stderr).
On the no-remote-PR probe, `pr` and `ci` came back `skipped`.

## `findings` table columns (from a real gate)

`findings[N]{id,severity,file,action,description}`

- **severity** observed: `info`, `warning`. (binary also knows `error`-class;
  not observed live.)
- **action** values: `auto-fix`, `no-op`, `ask-user` — confirmed in the
  binary's embedded skill text. Live run produced all `auto-fix`. Meanings
  (verbatim from binary):
  - `auto-fix` — objective issue the pipeline can safely fix.
  - `no-op` — informational only; nothing to do.
  - `ask-user` — challenges the user's deliberate intent / product behavior;
    escalate to the user, do not silently fix. "When in doubt, default to
    ask-user."

The run-level `findings:` scalar summarizes (e.g. `findings: none` or
`findings: 4 auto-fix`).

## `outcome:` values

Observed live: **`passed`**, **`cancelled`**.
From binary strings + embedded skill text (not triggered live): **`checks-passed`**, **`failed`**.
- `passed` — change validated; for the local-only probe this is terminal.
- `checks-passed` — change validated and CI green, but the PR is not yet merged
  (returned the moment checks are green rather than waiting). **(not observed live)**
- `cancelled` — run aborted (by `axi abort` or otherwise). Accompanied by an
  `error: "cancelled: ..."` line.
- `failed` — pipeline failed. **(not observed live as an outcome; a single
  *step* showed status `failed` when a run was aborted mid-review.)**

## Exit codes observed

- `axi run` reaching `outcome: passed` → **0**
- `axi run`/`axi respond` reaching a `gate:` (awaiting approval) → **0**
- `axi respond --action fix` → ... → `outcome: passed` → **0**
- `axi status` (any state, incl. cancelled) → **0**
- `axi logs` → **0**
- `axi abort` on an active run → **0**; on no active run → **0** (no-op)
- `axi run` on a branch with no started run → **1** (`no run started ...`)
- `axi respond` with no active gate → **1** (`no active run to respond to`)

## REAL captured examples

### 1. Gate with findings (`axi run` parked at review) — abridged

```
run:
  id: "01KW41FRKR2X05MNEV6Q7EN97A"
  branch: probe-findings
  status: running
  head: f354766e
  findings: 4 auto-fix
  steps[9]{step,status,findings,duration_ms}:
    intent,skipped,0,271
    rebase,completed,0,95
    review,awaiting_approval,4,31176
    test,pending,0,0
    document,pending,0,0
    lint,pending,0,0
    push,pending,0,0
    pr,pending,0,0
    ci,pending,0,0
gate:
  step: review
  status: awaiting_approval
  risk: low
  findings[4]{id,severity,file,action,description}:
    div-by-zero,warning,calc.py,auto-fix,divide() performs a / b with no zero check ...
    missing-argv,warning,calc.py,auto-fix,"main() reads sys.argv[1] and sys.argv[2] without checking argument count ..."
    non-int-args,info,calc.py,auto-fix,"int(sys.argv[1]) / int(sys.argv[2]) raises an unhandled ValueError ..."
    module-side-effect,info,calc.py,auto-fix,"main() is called unconditionally at import time ..."
help[4]: Run `no-mistakes axi respond --action approve` to accept this step and continue,Run `no-mistakes axi respond --action fix --findings <ids>` to have the pipeline fix the selected findings (do not edit files yourself),Run `no-mistakes axi respond --action skip` to skip this step,Run `no-mistakes axi logs --step review --full` to read the full step log
```

Note the `gate:` object carries `step`, `status: awaiting_approval`, a `risk`
level (`low` here), the `findings[N]{...}` table, and a `help[N]:` list of the
exact `respond` commands to issue. `axi status` while parked prints the same
`run:` + `gate:` blocks.

### 2. `axi respond --action fix` driving to completion — full stdout

```
run:
  id: "01KW41FRKR2X05MNEV6Q7EN97A"
  branch: probe-findings
  status: completed
  head: ae672ef9
  findings: none
  steps[9]{step,status,findings,duration_ms}:
    intent,skipped,0,271
    rebase,completed,0,95
    review,completed,0,79111
    test,completed,0,62178
    document,completed,0,36499
    lint,completed,0,31689
    push,completed,0,83
    pr,skipped,0,0
    ci,skipped,0,0
outcome: passed
fixes[1]{step,summary}:
  review,guard divide-by-zero and missing CLI args in calc.py
help[2]: "Summarize this pipeline run for the user in a concise, easily readable format: what was validated and what was found.",The pipeline fixed findings the original change missed (see `fixes`) - acknowledge the misses and list each fix so the user can review them.
```

A successful run after fixes emits an extra `fixes[N]{step,summary}` table.

### 3. Clean change — `outcome: passed`, no gate

```
outcome: passed
help[1]: "Summarize this pipeline run for the user in a concise, easily readable format: what was validated and what was found."
```
(full `run:`/`steps[9]` block precedes it; `findings: none`, no `gate:`.)

### 4. `axi abort` on active run + resulting `cancelled` status

```
aborted: true
run: "01KW41PRXGCNCQ7WPT7W2RSHCJ"
branch: probe-abort
```
then `axi status`:
```
run:
  ...
  status: cancelled
  ...
    review,failed,0,3725
    ...
outcome: cancelled
error: "cancelled: aborted by user"
```
`axi abort` with nothing active: `aborted: false` / `detail: no active run (no-op)`.

### 5. `axi logs --step review`

```
step: review
run: "01KW41FRKR2X05MNEV6Q7EN97A"
lines: 3 total
log[3]{line}:
  reviewing changes...
  ""
  "The change adds two lines ... The change is clean."
```

### 6. Zero-runs state (`axi status` before any push)

```
runs: 0 runs yet in this repository
help[1]: "Run no-mistakes axi run --intent \"the user's goal\" --yes to validate the current branch"
```

### 7. Error shapes

```
# axi run on a branch with no started run (exit 1)
error: "no run started for \"probe-change\": no previous run for branch probe-change"

# axi respond with no gate awaiting (exit 1)
error: no active run to respond to
help[1]: Run `no-mistakes axi run` to start one
```

## Not observed live (document gaps)

- **`outcome: checks-passed`** and **`outcome: failed`** — known from binary
  strings + the embedded skill text but not triggered. `checks-passed` requires
  a real PR + green CI (probe repo had no real remote, so `pr`/`ci` were
  `skipped`). `failed` would need a step to genuinely fail (e.g. failing tests).
- **`action: no-op` / `action: ask-user`** in a live findings table — the live
  review produced only `auto-fix`. Their definitions above are verbatim from the
  binary; an `ask-user` finding must be escalated to the user, never auto-fixed.
- **`respond --action approve` / `--action skip`** stdout — not exercised; per
  the gate `help[4]`, `approve` accepts the step and continues, `skip` skips it.
- **`severity: error`** rows — only `info`/`warning` seen live.
