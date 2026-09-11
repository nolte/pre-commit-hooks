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

- Each hook is one self-contained file under `hooks/`, named after its hook ID.
  **A POSIX shell script (`hooks/<id>.sh`, `set -euo pipefail`, `language:
  script`, no runtime dependency beyond `git`) is the default** and the right
  choice for every check that shells out to `git` and greps text.
  Reach for another interpreter only when the check genuinely needs it — see
  `spec/hook-authoring/` §4, which is authoritative on the choice. The one hook
  that does so today is `workflow-gate-integrity`
  (`hooks/workflow-gate-integrity.py`): it must read parsed workflow YAML, which
  a shell script cannot do. It stays on `language: script` — the entry is still
  a committed file in `hooks/`, so pre-commit resolves the path against this
  repository's clone — and asks for `python3` plus `PyYAML` on the consumer's
  PATH. `language: python` was tried and rejected: it builds a managed
  virtualenv and resolves `entry:` against that environment's console scripts,
  which would require turning this repository into an installable package.
  A hook whose interpreter or library is missing **must exit 2**, not 0 or 1, so
  that a scan which did not happen stays distinguishable from a clean one.
- Every hook is registered in `.pre-commit-hooks.yaml` with a stable `id`, a
  human `name`, a `description`, and its `language`.
- **Fail-open under `CI` is a rule about workflow guards, not about hooks in
  general.** A guard whose premise is the developer's local working copy —
  `guard-primary-checkout`, `guard-spec-translation-sync` — short-circuits to
  exit 0 when `CI` is set, because CI checks the branch out in a detached HEAD
  inside a normal clone where the premise no longer holds, and the hook would
  otherwise block every lint job. A correctness check that is meant to gate
  everywhere fails **closed** and runs under `CI` too; `workflow-gate-integrity`
  is that case, and a hook that inspects CI configuration while excusing itself
  from CI would not be a gate at all. `spec/hook-authoring/` §6 draws the same
  line. Decide deliberately per hook and state the decision in its header.
- Tunable behaviour is exposed via pre-commit `args:` (e.g.
  `--branch <name>`), parsed defensively with a sensible default — never
  hard-code a portfolio-specific value that a `main`-integrating repo can't
  override.
- Every hook has a matching self-test under `tests/test_<id>.sh` that builds
  throwaway git repos and asserts on exit codes — a shell test regardless of the
  hook's own backend. Run the whole suite (`task test`) before changing a hook.

## Common commands

```bash
# Lint this repo and dogfood the guard against itself
pre-commit run --all-files

# Run a hook's self-test
tests/test_guard-primary-checkout.sh
```
