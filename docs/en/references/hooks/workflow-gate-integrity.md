---
title: workflow-gate-integrity
audience:
  - hook-consumer-project
  - consumer-developer
  - consumer-ci
content_mode: reference
track: developer-docs
last_updated: 2026-09-11
---

# workflow-gate-integrity

Refuse a GitHub Actions gate that cannot report a failure. A check that cannot
go red is indistinguishable from one that is not running, and both look the
same downstream: green.

See [References → Common contract](../index.md#common-contract) for the pinning
and configuration conventions that apply across every hook. Two of them do
**not** apply here, and the exceptions are stated under
[Behaviour](#behaviour).

## Prerequisites

- [pre-commit](https://pre-commit.com) on the `PATH`.
- `python3` and [PyYAML](https://pypi.org/project/PyYAML/) on the `PATH`. Two
  of the five shapes read parsed workflow YAML, so the parser is not optional.
  If it is missing the hook exits **2** and scans nothing, rather than scanning
  partially and reporting a green that means less than it looks.
- A `git` repository. Read paths are resolved against its **tracked** files.

## Arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `--scan-root <path>` | `.github/workflows` | The directory scanned for workflow files (`.yml`, `.yaml`, recursively). |
| `--tree-root <path>` | the enclosing checkout | The checkout whose tracked files decide whether a referenced path exists. |
| `--list` | off | Also name every justified site when the check passes. |
| `--json` | off | Print findings as JSON instead of the human report. |

Arguments are supplied through pre-commit's `args:` list:

```yaml
hooks:
  - id: workflow-gate-integrity
    args: [--scan-root=.github/workflows]
```

## Behaviour

The hook reports five shapes. All of them have occurred in production.

1. **A discarded exit code** — `|| true` in a `run:` step. Often correct, which
   is why it needs a reason rather than a ban.
2. **`continue-on-error: true`** — the step or job cannot turn its check red.
   Legitimate for a reporter, not for anything that measures.
3. **A job reading `needs.<x>.outputs` without consulting `needs.<x>.result`**,
   while its own `if:` overrides GitHub's dependency gating with `always()`,
   `cancelled()` or `failure()`. A failed producer then leaves every output an
   empty string, every step skipped — and a job whose steps all skip *reports
   success*.
4. **A comment on a line reached through a trailing `\`** — the `#` ends the
   logical line, so the command runs truncated. The step goes red, which looks
   self-reporting, but the artefacts later steps gate on are never written, and
   those steps skip silently behind their own existence guards.
5. **A path the workflow reads that its own `paths:` filter excludes** — the
   one change most able to break a check is then the one change that never runs
   it.

Two conventions from the common contract do not apply:

- **This hook fails closed.** It does *not* short-circuit under `CI`. It checks
  CI configuration, so a gate that exempted itself from CI would be the very
  shape it exists to refuse.
- **It is not a shell script.** Shapes 3 and 5 need a YAML parser. The manifest
  still declares `language: script`, so pre-commit resolves the file against
  this repository's clone; the managed `language: python` backend would instead
  require this repository to be an installable package.

Exit codes are three-valued on purpose, because a scan that did not happen must
not look like a scan that found nothing:

| Exit | Meaning |
|------|---------|
| `0` | Every swallowed verdict carries a reason. |
| `1` | At least one site cannot fail and has no reason. |
| `2` | The scan did not run: missing parser, missing scan root, usage error. |

It is registered with `always_run: true` and `pass_filenames: false`, so it
scans the workflow directory on every commit regardless of which files are
staged. Detection is textual for shapes 1, 2, 4 and 5, so a swallowed exit code
spelled `|| :` or `; true` slips through; shape 3 reads parsed YAML but cannot
see through a composite action or a reusable workflow. The guarantee is not
exhaustiveness — it is that these shapes cannot be *added* without somebody
writing down why.

### The escape hatch

A site may stand by carrying a reason, on its own line or in the comment block
directly above it:

```yaml
# gate-integrity-ok: grep -c exits 1 on no match; the count is the result
- run: hits=$(grep -c '^kind:' file || true)
```

The reason is mandatory and must be at least 12 characters, so the marker
cannot be used as a bare silencer. For shape 3 it goes in the comment block
above the job key. Shape 5 accepts a marker anywhere in the same workflow
**provided the reason names the path** — a reference can sit inside a shell or
JavaScript string where `#` is a syntax error, and the honest place to write
"this reference deliberately does not widen the trigger" is beside the `paths:`
filter it declines to widen. Naming the path is what keeps that placement from
becoming a file-wide silencer.

## Example

```yaml
# .pre-commit-config.yaml in the consumer repository
repos:
  - repo: https://github.com/nolte/pre-commit-hooks
    rev: v1.0.0
    hooks:
      - id: workflow-gate-integrity
```

A workflow whose own filter excludes the pin file it reads:

```text
workflow-gate-integrity: 1 site(s) where a check cannot fail

  .github/workflows/security-nuclei-templates.yml:74: this workflow reads a file its own paths: filter excludes
      reads '.github/renovate-pins.yaml', which no paths: entry of this workflow covers

A check that cannot report a failure is indistinguishable from one that is
not running. Either restore the verdict, or say — where it stands, on the
same line or in the comment block directly above it — why the discarded
outcome is not a verdict:

    # gate-integrity-ok: <why this cannot hide a failure>
```

## Troubleshooting

- **Exit 2 with "PyYAML is not installed".** Install it into the interpreter
  pre-commit uses: `python3 -m pip install PyYAML`. The hook refuses to scan
  partially rather than report a green that covers three shapes out of five.
- **A finding on a `|| true` that is genuinely correct.** That is the expected
  case, not a false positive. Add the marker with a reason of at least 12
  characters; the point is that the reason exists in the file, not that the
  pattern is banned.
- **A path finding on a reference that should not widen the trigger.** Write
  the reason and name the path in it. The marker may then sit anywhere in that
  workflow, including beside the `paths:` filter.
- **The hook fires in CI and blocks a lint job.** That is deliberate; this hook
  fails closed. If the finding is legitimate, fix the workflow or justify the
  site. There is no `CI` bypass.
- **A finding disappears on one machine and not another.** Read paths resolve
  against **tracked** files. An untracked file that happens to be lying in the
  working tree does not count, which is what keeps the verdict identical on a
  workstation and on a runner.
- **Findings in a workflow directory that is not `.github/workflows`.** Point
  the hook at it with `args: [--scan-root=<path>]`.

## Related

- [`spec/hook-authoring`](../governance.md) §0 records the defect-class-guard
  method this hook implements, specified in
  [nolte/claude-shared#573](https://github.com/nolte/claude-shared/issues/573),
  and §9 the falsification rule its self-test satisfies.
