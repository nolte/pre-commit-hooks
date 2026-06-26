---
title: Contributing
audience:
  - hook-maintainer
  - documentation-author
content_mode: how-to
track: developer-docs
last_updated: 2026-06-26
---

# Contributing

The canonical entry point for adding a hook, changing an existing one, or
updating the rendered docs.
[`CLAUDE.md`](https://github.com/nolte/pre-commit-hooks/blob/main/CLAUDE.md)
records the same conventions for AI-assisted edits. Keep both documents in
sync when the contract changes.

## Hook conventions

Every hook follows the same contract. Keep it intact when editing or adding
hooks.

- **One script per hook.** Each hook is a self-contained script under
  `hooks/`, named after its hook ID (`hooks/<id>.sh`). No runtime
  dependencies beyond `git` and a POSIX-ish shell; `set -euo pipefail` at
  the top.
- **Registered in the manifest.** Every hook has a stable `id`, a human
  `name`, a `description`, and `language: script` in
  `.pre-commit-hooks.yaml`.
- **Fail open in automation.** Hooks short-circuit to exit 0 when `CI` is
  set, so the same hook installed locally never blocks a CI lint job.
- **Tunable via `args:`.** Expose tunable inputs through pre-commit `args:`
  (for example `--branch <name>`), parsed defensively with a sensible
  default. Don't hard-code a portfolio-specific value that a
  `main`-integrating repository can't override.

## Self-test contract

Every hook has a matching self-test under `tests/test_<id>.sh`. The test
builds throwaway git repositories under `tests/.sandbox/`, drives `HEAD`
into a known state, runs the hook, and asserts on its exit code — no
network, no global git side effects.

```bash
task test       # run the hook self-tests
tests/test_guard-primary-checkout.sh   # run one suite directly
```

Run the whole suite before changing a hook, and add cases for any new
behaviour or argument.

## Local checks

```bash
task            # list available tasks
task lint       # run every pre-commit hook (shellcheck, hygiene, the guard)
task test       # run the hook self-tests
task docs       # serve the mkdocs site locally
```

`task lint` and `task docs` delegate to the remote
[`nolte/taskfiles`](https://github.com/nolte/taskfiles) modules and depend
on the pre-provisioned virtual environments at `~/.venvs/development` and
`~/.venvs/docs`. When a venv is missing, the task fails on the first run;
the fix is to provision the venv, not to inline `pip install`.

## Documentation conventions

- `mkdocs-include-markdown-plugin` pulls the intro block from the README
  into the rendered home page through the `<!--intro-start-->` and
  `<!--intro-end-->` markers. Keep those markers in place.
- Every hook gets a page under `docs/en/references/hooks/` (and the matching
  translation under `docs/de/references/hooks/`) with the same schema: short
  intro, **Prerequisites**, **Arguments**, **Behaviour**, **Example**,
  **Troubleshooting**.
- New hook names and technical terms go into the local Vale vocabulary at
  `.github/styles/config/vocabularies/pre-commit-hooks/accept.txt`;
  otherwise the spelling-vale workflow fails on the first prose mention.

## Pull request flow

- Branch off `develop` in a dedicated worktree — the same parallel
  working-copies model the `guard-primary-checkout` hook enforces. The
  primary checkout stays on `develop`.
- Pull requests run the reusable workflows from
  [`nolte/gh-plumbing`](https://github.com/nolte/gh-plumbing) at a pinned
  tag (currently `v1.1.18`). Bump every workflow reference together when
  updating the pin.
- Merges are squash-only and automerge once checks pass. Renovate-driven
  dependency bumps follow the same path.
- Prose changes have to pass Vale (Microsoft + RedHat plus the
  [`nolte/vale-style`](https://github.com/nolte/vale-style) pack and the
  local `pre-commit-hooks` vocabulary).
