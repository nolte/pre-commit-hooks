---
title: guard-primary-checkout
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-06-26
---

# guard-primary-checkout

Block commits made directly in the primary checkout while it sits on a
feature branch. Feature work belongs in a dedicated
[git worktree](https://git-scm.com/docs/git-worktree) that branches off the
integration branch.

See [References → Common contract](../index.md#common-contract) for the
pinning, fail-open, and primary-checkout-versus-worktree conventions that
apply across every hook.

## Prerequisites

- [pre-commit](https://pre-commit.com) on the `PATH`.
- A `git` repository. The hook shells out to `git` only; it has no other
  runtime dependency.

## Arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `--branch <name>` | `develop` | The integration branch the primary checkout must stay on. Pass `--branch=main` for repositories that integrate on `main`. |

Arguments are supplied through pre-commit's `args:` list:

```yaml
hooks:
  - id: guard-primary-checkout
    args: [--branch=main]
```

## Behaviour

- **Enforces only in the primary checkout.** The hook compares the
  per-worktree git-dir with the shared git-common-dir; they're equal only
  in the primary checkout. In a linked worktree they differ, so the hook
  exits 0 — feature-branch commits belong there.
- **Allows the integration branch.** When the primary checkout is on the
  configured branch (default `develop`), the commit proceeds.
- **Blocks anything else.** On any other branch — or a detached HEAD — in
  the primary checkout, the commit is refused with exit 1 and a message that
  shows how to move the work into a worktree.
- **Fails open in CI.** When `CI` is set, the hook exits 0 immediately.
- **Never mutates state.** It only refuses the commit; the branch, index,
  and working tree are left untouched.

It's registered with `always_run: true` and `pass_filenames: false`, so it
fires on every commit regardless of which files are staged.

## Example

```yaml
# .pre-commit-config.yaml in the consumer repository
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

A commit attempted on a feature branch in the primary checkout:

```text
✖ Primary checkout is on branch 'feat/x', not 'develop' — commit blocked.

  The primary checkout (…) is for integration only and MUST stay
  on 'develop' at all times. Feature work happens on a feature
  branch in a dedicated worktree that branches off 'develop'.
```

## Troubleshooting

- **The hook blocks a legitimate commit on `main`.** The repository
  integrates on `main`, not `develop`. Configure it with
  `args: [--branch=main]`.
- **The hook doesn't fire at all.** Confirm `pre-commit install` ran in the
  clone and that the commit happens in the primary checkout. In a linked
  worktree the hook is silent by design.
- **CI commits are unexpectedly blocked.** They aren't: the hook exits 0
  whenever `CI` is set. If a local automation context needs the same
  bypass, set `CI=1` for that invocation.
- **A commit must land in the primary checkout to repair drift.** Run the
  git command from a worktree, or temporarily move the hook aside; the hook
  prints the worktree-based repair steps when it blocks.

## Related

- [`nolte/taskfiles`](https://github.com/nolte/taskfiles) `worktree` module
  (`task worktree:add`) creates the dedicated worktrees this hook steers you
  toward.
