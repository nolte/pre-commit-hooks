# pre-commit-hooks

[![Static Tests](https://github.com/nolte/pre-commit-hooks/actions/workflows/build-static-tests.yaml/badge.svg)](https://github.com/nolte/pre-commit-hooks/actions/workflows/build-static-tests.yaml)
[![Spelling Check](https://github.com/nolte/pre-commit-hooks/actions/workflows/spelling.yaml/badge.svg)](https://github.com/nolte/pre-commit-hooks/actions/workflows/spelling.yaml)

<!--intro-start-->
Reusable [pre-commit](https://pre-commit.com) hooks for the nolte portfolio.
Each hook ships as a small, dependency-free script and is consumed remotely
through pre-commit's standard `repos:` mechanism — there is no build step, the
scripts themselves are the product.
<!--intro-end-->

## Hooks

| Hook ID | Purpose | Key argument |
|---------|---------|--------------|
| `guard-primary-checkout` | Block commits made directly in the primary checkout while it sits on a feature branch — feature work belongs in a dedicated [git worktree](https://git-scm.com/docs/git-worktree). | `--branch <name>` (default `develop`) |
| `guard-spec-translation-sync` | Block a commit that stages one language of a `spec/<topic>/<lang>.md` set while leaving a tracked sibling translation unstaged — keeps multilingual specs in lockstep. | `--lang <code>` (default `en` `de`), `--spec-dir <path>` (default `spec`) |
| `workflow-gate-integrity` | Refuse a GitHub Actions gate that can't report a failure: a discarded exit code, `continue-on-error`, a job reading a dependency's outputs without its result, a comment truncating a continued command, or a file the workflow reads that its own `paths:` filter excludes. | `--scan-root <path>` (default `.github/workflows`) |

## Usage

<!--usage-start-->
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
<!--usage-end-->

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

`workflow-gate-integrity` scans `.github/workflows` by default. Point it
elsewhere the same way:

```yaml
      - id: workflow-gate-integrity
        args: [--scan-root=ci/workflows]
```

### Behaviour

The two guards are deliberately narrow and fail-open in automation;
`workflow-gate-integrity` is neither, and the difference is the point.

`guard-primary-checkout`:

- It enforces **only** in the primary checkout (where the per-worktree git-dir
  equals the shared git-common-dir). In a linked worktree, feature-branch
  commits are correct, so the hook allows them.
- It short-circuits to *allow* when `CI` is set, because CI checks out a
  detached HEAD in a plain clone — indistinguishable from a primary checkout
  on a feature branch — and the guard targets a developer's local commit, not
  the CI lint job.
- It leaves the branch untouched; it only refuses the commit and prints how to
  move the work into a worktree.

`workflow-gate-integrity` **fails closed**. It doesn't short-circuit under
`CI`, because it checks CI configuration and a gate that exempts itself from
CI would be the very shape it refuses. Its exit codes are three-valued so that
a scan which didn't happen stays distinguishable from one that found nothing:
`0` clean, `1` a site that can't fail and carries no reason, `2` the scan did
not run. A site may stand by carrying a `# gate-integrity-ok: <reason>`
comment, where the reason is mandatory and must be more than a word.

## Prerequisites

- [pre-commit](https://pre-commit.com) on the `PATH`.
- A `git` repository. The two `guard-*` hooks shell out to `git` only.
- For `workflow-gate-integrity` additionally `python3` and
  [PyYAML](https://pypi.org/project/PyYAML/) on the `PATH`: two of the five
  shapes it detects read parsed workflow YAML. Without the parser it exits `2`
  and scans nothing, rather than scanning partially and reporting green.

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
