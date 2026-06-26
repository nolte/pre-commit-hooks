---
title: Getting started
audience:
  - hook-consumer-project
  - consumer-developer
content_mode: tutorial
track: developer-docs
last_updated: 2026-06-26
---

# Getting started

This tutorial walks a consumer project through wiring in the
`guard-primary-checkout` hook for the first time. By the end, a `git commit`
attempted in the primary checkout while it sits on a feature branch is
blocked, and the same commit succeeds from a worktree.

## Prerequisites

- [pre-commit](https://pre-commit.com) on the `PATH`.
- A `git` repository checked out locally, with a `.pre-commit-config.yaml`
  (an empty `repos: []` file is enough to start).

## 1. Add the repository to the consumer config

Add the hook repository to the consumer's `.pre-commit-config.yaml` and pin a
released tag:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

The `rev` pins to a released tag, so behaviour is deterministic across
machines. Replace `v1.0.0` with the latest entry from
[the releases page](https://github.com/nolte/pre-commit-hooks/releases).

## 2. Install the hook

```bash
pre-commit install
```

This wires the hook into the local clone's `.git/hooks/pre-commit`. Because
the hook is installed in the shared hooks directory, it also fires inside
linked worktrees — where it deliberately stays silent.

## 3. See it block a misplaced commit

With the primary checkout on a feature branch, a commit is refused:

```bash
git switch -c feat/demo
echo change >> file.txt && git add file.txt
git commit -m "feat: demo"
# ✖ Primary checkout is on branch 'feat/demo', not 'develop' — commit blocked.
```

The hook leaves the branch untouched; it only refuses the commit and prints
how to move the work into a worktree.

## 4. Commit from a worktree instead

Create a dedicated worktree for the feature branch and commit there. The
[`nolte/taskfiles`](https://github.com/nolte/taskfiles) `worktree` module
makes this one command:

```bash
task worktree:add -- feat/demo
cd "$(task worktree:root)/<repo>/demo"
git commit -m "feat: demo"   # succeeds — this is a linked worktree
```

## 5. Configure the integration branch (optional)

The hook defaults to `develop`. A repository that integrates on `main`
configures it through `args`:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
        args: [--branch=main]
```

## What to read next

- [References → Hooks](../references/index.md) documents every hook, its
  arguments, and its exact behaviour.
- [Guides → Contributing](../guides/contributing.md) covers adding a new
  hook or changing an existing one.

## Sources

- [`README.md`](https://github.com/nolte/pre-commit-hooks/blob/main/README.md)
  (usage section)
- `hooks/guard-primary-checkout.sh`
