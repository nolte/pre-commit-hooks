---
name: develop-pre-commit-hook
description: >-
  This skill should be used when the user wants to add a new pre-commit hook to
  this repository, design or scaffold a hook, change an existing hook's
  behaviour, or asks "build a hook that …", "new pre-commit hook", "add a guard
  for …". Also handles the equivalent German requests ("baue einen Hook",
  "neuen pre-commit-Hook hinzufügen", "Hook für … entwickeln"). It grounds every
  design decision in spec/hook-authoring/ and produces a hook that conforms to
  this repo's contract: a self-contained hooks/<id>.sh, a manifest entry, a
  self-test, docs, and the supporting wiring. Don't use it to consume a
  third-party hook (that's editing .pre-commit-config.yaml), to author the
  domain spec itself (edit spec/hook-authoring/), or for unrelated shell
  scripting.
---

# Develop a targeted pre-commit hook

Author a **single, targeted** pre-commit hook for this repository — one scoped to
one well-defined check — end to end, from design through tests and docs.

## Step 0 — Load the knowledge base

**Read [`spec/hook-authoring/en.md`](../../../spec/hook-authoring/en.md) first.**
It is the verified reference for manifest fields, language backends, stages, file
targeting, the hook contract, performance, anti-patterns, and supply-chain
security. This skill operationalises that spec; do not restate or contradict it.
The repo's own contract lives in `CLAUDE.md` and `docs/en/guides/contributing.md`.

## Step 1 — Design the hook (spec §12 targeting checklist)

Walk the checklist from `spec/hook-authoring/en.md` §12 with the user, settling
each decision before writing code. Capture answers explicitly:

1. **Trigger** — which git event's content does the check need? → `stages`
   (`pre-commit` / `commit-msg` / `pre-push` / `manual`).
2. **Scope** — per-file or whole-repo? → `pass_filenames` (+ `always_run` for
   whole-repo).
3. **Files** — narrow with `types`/`types_or`/`files`/`exclude`; verify the tags
   with `identify-cli <path>` before committing to them.
4. **Runtime** — pick the lightest `language`. In **this repo the default is
   `language: script`** (a committed `hooks/<id>.sh`); only diverge to
   `pygrep`/`fail` for trivial pattern/forbid checks if the user prefers, and
   flag that as a deviation from the script-per-hook convention.
5. **Checker or fixer** — reports only, or mutates files (and so fails the run)?
6. **Configurable inputs** — expose via `args` with safe defaults; never
   hard-code a portfolio-specific value a consumer can't override.
7. **Where it gates** — decide fail-open vs fail-closed. This repo's contract:
   **fail open under `CI`** (short-circuit `exit 0` when `CI` is set).
8. **Shared state** — set `require_serial: true` only if it touches resources
   outside the passed files.

Pick a kebab-case `id`. The script, manifest id, test name, and docs page all key
off it.

## Step 2 — Write the hook script (`hooks/<id>.sh`)

- Self-contained, `#!/usr/bin/env bash`, `set -euo pipefail` at the top. No
  runtime dependency beyond `git` and a POSIX-ish shell.
- Parse `args` defensively (a `while`/`case` loop) with the sane default from
  step 1; ignore unknown args/filenames unless the hook is path-aware.
- Fail-open guard near the top: `if [ -n "${CI:-}" ]; then exit 0; fi` (unless the
  hook is a correctness/security check meant to gate everywhere — then justify
  fail-closed).
- Operate on what pre-commit passes (the staged set), never the working tree
  directly. Quote every path expansion.
- On failure, print to **stderr** *why* it failed and *how to repair it* (mirror
  the remediation-recipe style of `hooks/guard-primary-checkout.sh`).
- `chmod +x hooks/<id>.sh`.

Use `hooks/guard-primary-checkout.sh` as the structural reference.

## Step 3 — Register it in the manifest (`.pre-commit-hooks.yaml`)

Add one entry with a stable `id`, human `name`, `description`, `entry:
hooks/<id>.sh`, `language: script`, and the targeting fields decided in step 1
(`stages`, `pass_filenames`, `always_run`, `types`/`files`, `require_serial`).
Keep entries ordered and the consumer-usage comment block intact.

## Step 4 — Write the self-test (`tests/test_<id>.sh`)

Follow `tests/test_guard-primary-checkout.sh`: build throwaway repos under
`tests/.sandbox/`, drive `HEAD`/the index into known states, run the hook, assert
on **exit codes**. No network, no global git-config side effects. Cover the pass
case, the fail case, **every `args` branch**, the **fail-open (`CI=1`)** path, and
any edge states (detached HEAD, worktrees). `chmod +x tests/test_<id>.sh`.

**Then wire it into `Taskfile.yml`** — the `test` task lists each suite
explicitly; add `tests/test_<id>.sh` so `task test` runs it.

## Step 5 — Document it (en + de)

Add a reference page under **both** `docs/en/references/hooks/<id>.md` and
`docs/de/references/hooks/<id>.md`, using the established schema: frontmatter
(`title`, `audience`, `content_mode: reference`, `track`, `last_updated`), short
intro, **Prerequisites**, **Arguments** (table), **Behaviour**, **Example**,
**Troubleshooting**, optional **Related**. Mirror
`docs/en/references/hooks/guard-primary-checkout.md`.

Then:

- Add the nav entry under `Hooks:` in **`mkdocs.yml`** (the hook id is the label).
- Add a row to the **README.md** `## Hooks` table (Hook ID · Purpose · Key
  argument).
- Add the new hook id and any new technical terms to
  `.github/styles/config/vocabularies/pre-commit-hooks/accept.txt`, or the
  spelling-vale gate fails on the first prose mention.

> **The CI prose gate is spelling-only.** It enforces `Vale.Spelling` /
> `Vale.Terms`, not the full Microsoft style. The shipped docs deliberately
> carry `Microsoft.*` findings (`" — "` dashes, `It is`, passive voice), so
> don't chase those — match the existing pages' voice and fix only spelling.
> German pages set `Vale.Spelling = NO`, so vocab additions are for the English
> page.

## Step 6 — Repo-specific requirements (only if needed)

If the hook encodes requirements **not** owned by a portfolio spec, capture them
under `spec/<topic>/{en,de}.md` (canonical English) and link them from
`spec/README.md`, per that file's convention. Hooks operationalising an existing
portfolio spec just reference it. Do not duplicate `spec/hook-authoring/`.

## Step 7 — Verify

Run, and report results honestly:

```bash
task test                          # all self-tests, including the new one
pre-commit run --all-files         # dogfood: lint + the new hook against this repo
pre-commit validate-manifest .pre-commit-hooks.yaml   # manifest shape
vale --filter='.Name == "Vale.Spelling"' docs/en/references/hooks/<id>.md   # spelling gate
task docs                          # mkdocs build --strict (en + de must build)
pre-commit try-repo . <id>         # optional end-to-end run through the framework
```

Every gate must pass before the hook is done. If a test fails, surface the
output; don't paper over it.

Notes from real runs:

- **`mkdocs build --strict` catches broken cross-links.** Translated pages must
  use the *translated* anchor (e.g. the de page links `../index.md#gemeinsamer-vertrag`,
  not `#common-contract`). Mismatches surface here, not in Vale.
- **`pre-commit run --all-files` skips a hook whose `files` match only untracked
  paths** — pre-commit's candidate set is tracked + staged files. A
  `pass_filenames: false` hook reading `git diff --cached` correctly reports
  nothing to do when its targets aren't staged; rely on the self-test for the
  block path.
- **The dogfood `guard-primary-checkout` failure is environmental**, not the new
  hook — it fires whenever the primary checkout sits on a feature branch.

## Hard rules

- **Spec-grounded.** Every design choice traces to `spec/hook-authoring/`; the
  repo contract (script-per-hook, fail-open under `CI`, `args`-tunable, self-test)
  is non-negotiable.
- **One hook, one concern.** Targeted, not a grab-bag. If the user describes two
  checks, make two hooks.
- **Complete or not done.** A hook is finished only when *all* artifacts exist:
  `hooks/<id>.sh`, manifest entry, `tests/test_<id>.sh`, `Taskfile.yml` wiring,
  en+de docs, mkdocs nav, README row, Vale vocab — and every gate in step 7 is
  green.
- **No silent fail-closed.** Defaulting to fail-closed (gating CI) is a deliberate
  choice the user must confirm; the repo default is fail-open under `CI`.
- **Don't hard-code portfolio specifics.** Tunables go through `args` with
  defaults a `main`-integrating repo can override.
