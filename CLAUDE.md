# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of reusable [pre-commit](https://pre-commit.com) hooks for the
nolte portfolio. Downstream projects consume them remotely via pre-commit's
`repos:` mechanism, pinned to a released tag. There is no build artifact — the
hook scripts under `hooks/` are the product, and `.pre-commit-hooks.yaml` is
the manifest that exposes them.

## Module conventions

Preserve this contract when editing or adding hooks:

- Each hook is one self-contained script under `hooks/`, named after its hook
  ID (`hooks/<id>.sh`). No runtime dependencies beyond `git` and a POSIX-ish
  shell; `set -euo pipefail` at the top.
- Every hook is registered in `.pre-commit-hooks.yaml` with a stable `id`, a
  human `name`, a `description`, and `language: script`.
- Hooks fail **open** in automation: short-circuit to exit 0 when `CI` is set,
  so the same hook installed locally does not block CI lint jobs.
- Tunable behaviour is exposed via pre-commit `args:` (e.g.
  `--branch <name>`), parsed defensively with a sensible default — never
  hard-code a portfolio-specific value that a `main`-integrating repo can't
  override.
- Every hook has a matching self-test under `tests/test_<id>.sh` that builds
  throwaway git repos and asserts on exit codes. Run the whole suite before
  changing a hook.

## Common commands

```bash
# Lint this repo and dogfood the guard against itself
pre-commit run --all-files

# Run a hook's self-test
tests/test_guard-primary-checkout.sh
```
