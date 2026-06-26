---
title: guard-spec-translation-sync
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-06-26
---

# guard-spec-translation-sync

Block a commit that stages one language of a multilingual specification topic
while leaving a tracked sibling translation behind. It keeps every
`spec/<topic>/<lang>.md` set moving in lockstep — one canonical language, the
rest strict translations.

See [References → Common contract](../index.md#common-contract) for the pinning,
fail-open, and primary-checkout-versus-worktree conventions that apply across
every hook.

## Prerequisites

- [pre-commit](https://pre-commit.com) on the `PATH`.
- A `git` repository whose specs follow the `spec/<topic>/<lang>.md` layout. The
  hook shells out to `git` only; it has no other runtime dependency.

## Arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `--lang <code>` | `en` `de` | A language that must stay in sync. Repeat the flag for each language (`--lang=en --lang=de --lang=fr`). A topic with only one configured language is never blocked. |
| `--spec-dir <path>` | `spec` | The root directory holding `<topic>/<lang>.md` trees. |

Arguments are supplied through pre-commit's `args:` list:

```yaml
hooks:
  - id: guard-spec-translation-sync
    args: [--lang=en, --lang=de, --spec-dir=spec]
```

## Behaviour

- **Inspects the staged set, not a file list.** Registered with
  `pass_filenames: false`, the hook reads the staged paths itself via
  `git diff --cached`. That is deliberate: pre-commit may split a per-hook file
  list across parallel processes, which could separate an `en.md`/`de.md` pair
  and cause a false positive. Reading the whole staged set once avoids that.
- **Enforces lockstep per topic.** When at least one configured `<lang>.md` of a
  topic is staged, every configured language whose file is **tracked in `HEAD`**
  for that topic must also be staged. A missing, tracked sibling blocks the
  commit with exit 1 and lists the unstaged files.
- **Ignores brand-new topics.** A topic with no tracked sibling yet (for example
  a freshly created `spec/<topic>/en.md` with no `de.md` in `HEAD`) is allowed —
  that is a completeness concern, not a sync concern.
- **Fails open in CI.** When `CI` is set, the hook exits 0 immediately; CI runs
  `pre-commit run --all-files`, where there is no staged set to reason about.
- **Never mutates state.** It only refuses the commit; the index and working tree
  are left untouched.

## Example

```yaml
# .pre-commit-config.yaml in the consumer repository
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: guard-spec-translation-sync
```

A commit that stages only the canonical language of an existing topic:

```text
✖ Spec translations out of sync — commit blocked.

  The nolte spec convention keeps every spec/<topic>/<lang>.md in
  lockstep. You staged one language of a topic but left its tracked
  sibling translation(s) unstaged:

    spec/hook-authoring/de.md
```

## Troubleshooting

- **The hook blocks a legitimate, deliberate work-in-progress.** Bypass the
  single commit with `git commit --no-verify`, then bring the translation in sync
  in a follow-up.
- **A new language should be enforced.** Add it to the `args` list
  (`--lang=fr`). The hook only requires languages it is told about.
- **Specs live outside `spec/`.** Point the hook at the right root with
  `--spec-dir=<path>`.
- **CI commits are unexpectedly blocked.** They aren't: the hook exits 0 whenever
  `CI` is set. To enforce translation parity in CI, run a dedicated job rather
  than this commit-time guard.

## Related

- [`spec/hook-authoring/`](https://github.com/nolte/pre-commit-hooks/tree/main/spec/hook-authoring)
  — the reference knowledge base this hook was designed against.
