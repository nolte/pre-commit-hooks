---
title: References
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: meta
track: developer-docs
last_updated: 2026-06-26
---

# References

Information-oriented documentation. Use this section to look up the contract
of each hook and the portfolio conventions that govern the repository.

## Hook references

One page per hook under `hooks/`. Every page follows the same schema (short
intro, **Prerequisites**, **Arguments**, **Behaviour**, **Example**,
**Troubleshooting**).

- [guard-primary-checkout](hooks/guard-primary-checkout.md): block commits
  made in the primary checkout while it sits on a feature branch.
- [guard-spec-translation-sync](hooks/guard-spec-translation-sync.md): block a
  commit that stages one language of a multilingual spec topic while leaving a
  tracked sibling translation unstaged.
- [workflow-gate-integrity](hooks/workflow-gate-integrity.md): refuse a GitHub
  Actions gate that can't report a failure.

## Common contract

These rules hold for every hook in the collection. Hook pages don't repeat
them; instead, they reference this section.

### Consumed remotely, pinned by tag

Hooks are consumed through pre-commit's standard `repos:` mechanism. The
`rev` field is the single point of pinning:

```yaml
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-primary-checkout
```

Pin to a released tag for deterministic behaviour. Renovate bumps the `rev`
in the consumer's config like any other dependency.

### Fail open in automation — for workflow guards

A **workflow guard** short-circuits to *allow* when the `CI` environment
variable is set. CI checks the branch out in a detached HEAD inside a plain
clone, which is indistinguishable from a primary checkout on a feature branch;
these hooks target a developer's local commit, not the CI lint job.
`guard-primary-checkout` and `guard-spec-translation-sync` are of this kind.

A **correctness check** doesn't get that exemption. It runs under `CI` too and
fails closed, because a check that excuses itself from the environment it's
meant to gate isn't a gate. `workflow-gate-integrity` is of this kind, and its
page says so explicitly. Each hook page names its kind under **Behaviour**.

### Primary checkout versus linked worktree

Hooks that enforce the parallel-working-copies model act only in the primary
checkout — distinguished by the per-worktree git-dir equalling the shared
git-common-dir. In a linked worktree, feature-branch work is correct, so the
hooks stay silent.

### Configuration via `args:`

Tunable inputs are exposed through pre-commit `args:` with a sensible
default. Each hook page lists its arguments in the **Arguments** table.

## Repository governance

- [Governance and specs](governance.md): portfolio conventions, reusable
  workflows, dependency governance, Vale stack, Probot settings.

## Sources

- `.pre-commit-hooks.yaml` (canonical hook manifest)
- `hooks/<id>.sh` (canonical hook scripts)
- [`CLAUDE.md`](https://github.com/nolte/pre-commit-hooks/blob/main/CLAUDE.md)
