# shipshape

`git push`, but make it clean. One command drives a change from intent → plan → architecture
diagram → build → review → a hard pre-push quality gate → a clean PR, with up-to-date diagrams.

It conducts existing tools instead of reinventing them. The hard gate is
[`no-mistakes`](https://github.com/kunchenguid/no-mistakes); diagrams use a live canvas
([`glimpse`](https://github.com/YushengAuggie/glimpse)) when available, or fall back to files.

## Install (one command)

```sh
git clone https://github.com/YushengAuggie/shipshape && cd shipshape && ./install.sh
```

This installs the `shipshape` skill and `no-mistakes` (the only hard dependency). `glimpse` is
optional. For agents other than Claude Code, set `SHIPSHAPE_SKILLS_DIR` to your skills folder.

## Use

In any git repo:

```sh
no-mistakes init        # once per repo
/shipshape <task>       # do the work and drive it to a clean PR
/shipshape              # gate already-committed work on the current branch
```

## The 7 phases

0 capture intent · 1 plan · 2 architecture diagram (approval) · 3 build · 4 review ·
5 no-mistakes gate · 6 post-gate diagram · 7 summary.

Diagrams are written at plan-time (architecture) and after the gate (truthful change diagram,
attached to the PR). Review runs early (`/crew` if present, else bundled lenses) and the gate
enforces tests/lint/docs before anything reaches your remote.

## Dependencies

| Tier | What |
|------|------|
| Required | `no-mistakes` (installed by `install.sh`) |
| Bundled | the skill, diagram template + render script, review lenses |
| Optional | `glimpse` (live canvas; degrades to files) |
| Enhance | `/crew`, superpowers planning (used if present) |

MIT licensed.
