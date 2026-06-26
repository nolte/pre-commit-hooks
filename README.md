# pre-commit-hooks

Reusable [pre-commit](https://pre-commit.com) hooks for the nolte portfolio.
Each hook ships as a small, dependency-free script and is consumed remotely
through pre-commit's standard `repos:` mechanism — there is no build step, the
scripts themselves are the product.

## Hooks

| Hook ID | Purpose | Key argument |
|---------|---------|--------------|
| `guard-primary-checkout` | Block commits made directly in the primary checkout while it sits on a feature branch — feature work belongs in a dedicated [git worktree](https://git-scm.com/docs/git-worktree). | `--branch <name>` (default `develop`) |

## Usage

Add the repository to the consumer's `.pre-commit-config.yaml` and pin a
released tag:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

Then install the hook into the local clone once:

```bash
pre-commit install
```

From then on, every `git commit` in the primary checkout is blocked while the
checkout is on a feature branch (`feat/…`, `fix/…`, etc.). Commit from a
worktree instead — see [`nolte/taskfiles`](https://github.com/nolte/taskfiles)
`worktree:add` for creating one.

### Configuration

The integration branch defaults to `develop`. A repository that integrates on
`main` configures it with `args`:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
        args: [--branch=main]
```

### Behaviour

`guard-primary-checkout` is deliberately narrow and fail-open in automation:

- It enforces **only** in the primary checkout (where the per-worktree git-dir
  equals the shared git-common-dir). In a linked worktree, feature-branch
  commits are correct, so the hook allows them.
- It short-circuits to *allow* when `CI` is set, because CI checks out a
  detached HEAD in a plain clone — indistinguishable from a primary checkout
  on a feature branch — and the guard targets a developer's local commit, not
  the CI lint job.
- It leaves the branch untouched; it only refuses the commit and prints how to
  move the work into a worktree.

## Prerequisites

- [pre-commit](https://pre-commit.com) on the `PATH`.
- A `git` repository (the hooks shell out to `git` only; no other runtime).

## Why this exists

The nolte portfolio follows a parallel-working-copies model: the primary
checkout is for integration only and stays on its integration branch at all
times, while every change happens on a feature branch inside a dedicated git
worktree. `guard-primary-checkout` is the commit-time backstop for the most
common drift — committing feature work directly in the primary checkout.

## Related repositories

- [nolte/taskfiles](https://github.com/nolte/taskfiles) — the `worktree`
  module (`task worktree:add`) that creates the dedicated worktrees this hook
  steers you toward.

## Development

Run the hooks against this repository (dogfooding) and the self-test:

```bash
pre-commit run --all-files
tests/test_guard-primary-checkout.sh
```

## License

[MIT](./LICENSE)
