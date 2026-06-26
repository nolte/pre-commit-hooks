# Spec: Authoring targeted pre-commit hooks

> Canonical language: **English**. The German file (`de.md`) is a translation kept
> strictly in sync; edit `en.md` first and propagate.

## Purpose

Domain knowledge for designing, building, distributing, and securing reusable
[pre-commit](https://pre-commit.com) hooks. This spec is the **reference knowledge
base** a skill consults when it has to develop a *targeted* hook — one scoped to a
single, well-defined check rather than a grab-bag script. It is descriptive
reference material, not a step-by-step workflow.

Every normative statement here was verified against the official pre-commit
documentation, the `pre-commit/pre-commit` and `pre-commit/pre-commit-hooks`
source manifests, the `identify` library, and the git `githooks` reference. See
[Sources](#sources). Where a claim is contested or version-dependent, it is
flagged inline.

## 1. Mental model — how pre-commit executes a hook

- pre-commit is a **multi-language framework** for managing git hooks (~260k
  projects; the framework itself is ~97% Python). It exists because git's
  client-side hooks live under `.git/hooks`, are not copied on `clone`, and must
  be installed per checkout — a framework installs and manages them.
- Two YAML files define the contract:
  - **`.pre-commit-config.yaml`** — the *consumer* side. Lists `repos:`, each
    pinned to a `rev`, each selecting hooks by `id` and optionally overriding
    behaviour (`args`, `files`, `stages`, …).
  - **`.pre-commit-hooks.yaml`** — the *hook-repository manifest*. The product of
    a hook repo. One entry per hook id. **This is what a hook author writes.**
- **Staged-content execution is the core invariant.** pre-commit runs hooks
  against the *staged* contents only. It temporarily stashes unstaged changes
  (including the unstaged remainder when a file is partially staged via
  `git add -p`) for the duration of the run, so the hook sees exactly what would
  be committed. A hook must therefore operate on what pre-commit hands it, **not**
  read the working tree directly — see [Anti-patterns](#10-anti-patterns).
- **Failure signal:** a hook fails if it **exits nonzero OR modifies files.**
  Both are treated as a failed run. (Verbatim from pre-commit.com "Creating new
  hooks": *"The hook must exit nonzero on failure or modify files."*) Creating a
  new *untracked* file is a minor exception that does not by itself fail the run.
- A `pre-commit`-stage failure aborts `git commit`. The developer can bypass any
  hook with `git commit --no-verify` (`-n`) — so hooks are advisory at the local
  layer; enforcement still belongs in CI.

## 2. The manifest (`.pre-commit-hooks.yaml`)

One list entry per hook. **Required fields:** `id`, `name`, `entry`, `language`.
Everything else is optional with a default. (`description` is *optional*,
default `''` — it is not a required field, despite often appearing alongside the
required four.)

| Field | Default | Meaning |
|---|---|---|
| `id` | — (required) | Stable identifier consumers reference in `.pre-commit-config.yaml`. |
| `name` | — (required) | Human-readable label shown in pre-commit's run output. |
| `entry` | — (required) | The executable command pre-commit runs. A script path (`hooks/foo.sh`), a console-script entry point shipped by the hook's own package, or — for `language: fail`/`pygrep` — a message/pattern. pre-commit appends the target filenames unless `pass_filenames: false`. |
| `language` | — (required) | How pre-commit installs/runs the hook. See [§4](#4-language-backends). |
| `description` | `''` | Longer human description. |
| `files` | `''` (all) | Python regex (matched with `re.search`, **not** anchored) restricting which paths the hook runs against. Anchor explicitly with `^…$` when needed. |
| `exclude` | `^$` (none) | Python regex of paths to drop from the `files` set. |
| `types` | `[file]` | `identify` tags a file must **all** match (AND). |
| `types_or` | `[]` | `identify` tags where **any** match qualifies (OR). |
| `exclude_types` | `[]` | `identify` tags to drop. |
| `always_run` | `false` | Run even when no files match the filters. |
| `pass_filenames` | `true` | Append matched filenames to `entry`. Set `false` for hooks that act on the repo as a whole. |
| `require_serial` | `false` | Force a single process (no parallel file batching). See [§7](#7-performance). |
| `stages` | all stages | Which git stages the hook applies to. See [§3](#3-stages--git-hook-types). |
| `args` | `[]` | Default arguments appended to `entry`. Consumers can override. |
| `additional_dependencies` | `[]` | Extra packages installed into the hook's managed environment. |
| `minimum_pre_commit_version` | `'0'` | Minimum framework version required. |
| `alias` | — | Optional second id consumers may select the hook by. |
| `verbose` | `false` | Always print output even on success. |
| `language_version` | `default` | Pin the backend toolchain version (e.g. `python3.11`). |

**Validation:** pre-commit ships `pre-commit validate-manifest` (CLI) and a
consumable `validate_manifest` hook to check a manifest's shape. Run it in the
hook repo's own CI.

## 3. Stages / git hook types

A hook declares the git stages it applies to via `stages`. The full set:

`commit-msg`, `post-checkout`, `post-commit`, `post-merge`, `post-rewrite`,
`pre-commit`, `pre-merge-commit`, `pre-push`, `pre-rebase`, `prepare-commit-msg`,
and the special **`manual`** stage.

- **Stage names match the git hook names as of pre-commit v3.2.0+.** Earlier
  versions used `commit`, `push`, `merge-commit`; these mapped to `pre-commit`,
  `pre-push`, `pre-merge-commit`. Declaring `minimum_pre_commit_version: 3.2.0`
  is appropriate when relying on the new names.
- **`pre-commit`** — runs before the commit message is entered; nonzero aborts
  the commit. The default and most common stage. Bypassable with `--no-verify`.
- **`commit-msg`** — git invokes it with one parameter: the path to a temp file
  holding the commit message. Use for message-format enforcement; nonzero aborts.
- **`prepare-commit-msg`** — runs before the editor opens; can pre-populate the
  message.
- **`pre-push`** — runs during `git push`, before the push takes place, and can
  prevent it entirely; receives the remote name/location as parameters and the
  refs to be updated on stdin. Right place for slower checks that should still
  gate sharing without slowing every commit. *(The Pro Git book phrases the
  timing as "after the remote refs have been updated but before objects are
  transferred"; the canonical `githooks(5)` man page states only that it runs
  before the push occurs and can prevent it — prefer the cautious framing.)*
- **`post-*`** (`post-checkout`, `post-commit`, `post-merge`, `post-rewrite`) —
  informational; run after the fact and cannot abort the operation.
- **`manual`** — never triggered automatically by any git hook. Invoked only via
  `pre-commit run --hook-stage manual <id>`. Use for checks that should exist in
  the repo but must not run on every commit (expensive or opt-in tooling).

**Choosing a stage is the first targeting decision:** match the stage to the git
event whose content the check needs (message → `commit-msg`; staged diff →
`pre-commit`; about-to-be-pushed refs → `pre-push`; opt-in → `manual`).

## 4. Language backends

`language` tells pre-commit how to install and run the hook. Pick the **lightest
backend that satisfies the dependency needs.**

| `language` | Use it when… | Notes |
|---|---|---|
| `script` | The hook is a self-contained script committed in the hook repo. | No environment management; `entry` is the script path. This repo's convention for shell hooks. |
| `system` | The required command is assumed already on `PATH`. | No install step; fastest, but consumer must provide the tool. |
| `fail` | The hook must **fail unconditionally** on any matched file. | `entry` is the failure *message*, not a command. Pair with `files`/`types` to forbid paths (e.g. block committed submodules). |
| `pygrep` | The check is "no file may contain pattern X". | Built-in; `entry` is a Python regex. No external process. Ideal for simple forbidden-content guards. |
| `python` | The hook is distributed as a Python package. | Managed isolated venv; `entry` is a `console_scripts` entry point; extra deps via `additional_dependencies`. |
| `node` / `ruby` / `rust` / `golang` / others | The hook ships in that ecosystem. | Managed isolated environment built per ecosystem; `language_version` pins the toolchain. |
| `docker` / `docker_image` | The check needs a container. | Heaviest startup cost; excluded from pre-commit.com's curated listing. Avoid for hooks meant to run on every commit unless unavoidable. |

For a *targeted* hook with no runtime dependency beyond git and a POSIX shell,
`script` (a committed `hooks/<id>.sh`) or `pygrep`/`fail` (no script at all) are
the right defaults. Reach for `python`/`node`/etc. only when the check genuinely
needs that runtime.

## 5. File targeting (which files a hook sees)

The candidate file set is computed from five filters, **all combined with AND**:

- `files` and `exclude` — Python regexes over the path (`re.search`).
- `types`, `types_or`, `exclude_types` — tags from the **`identify`** library.
  Within `types`, all tags must match (AND); within `types_or`, any tag qualifies
  (OR); `exclude_types` removes matches.

`identify` returns a **set of orthogonal tags** for each file simultaneously —
file kind, text/binary, executability, and language — so one file matches several
at once (a Python file → `file, text, python, non-executable`). Resolution
pipeline: file type → executability → extension (stop if recognised) → otherwise
leading-bytes binary-vs-text → for text, the shebang. So an extensionless script
starting with `#!/usr/bin/env python3` is tagged `python`. Inspect a file's tags
directly with the `identify-cli` command (`--filename-only` for path-only mode)
to choose the right `types`.

Pitfalls:

- **Jupyter `.ipynb` files are tagged `json`** (their underlying format). A JSON
  hook will also process notebooks unless you add `exclude_types: [jupyter]`.
- `default types` is `[file]` — i.e. without narrowing, a hook runs on every
  (non-binary-excluded) file.
- **`--all-files` does NOT bypass per-hook filters.** It only widens the
  *candidate* set to the whole repo; `files`/`types`/`exclude`/`exclude_types`
  are still applied on top. (Maintainer-confirmed; a recurring misreport.)

For hooks that act on the repo as a whole rather than per file, set
`pass_filenames: false` and usually `always_run: true` (the pattern used by
`no-commit-to-branch`).

## 6. The hook contract (behavioural design)

- **Exit codes:** `0` = success (commit proceeds). Any nonzero = failure (commit
  aborts). A Python check function conventionally accepts a single filename or a
  sequence of filenames and returns a bool or int exit status.
- **File modification counts as failure.** Formatter-style hooks that rewrite
  files report failure on the run that changed something, so the developer
  re-stages and re-commits. Design intentionally: a *checker* leaves files
  untouched and only reports; a *fixer* mutates and fails the run.
- **stdout/stderr:** print actionable diagnostics. pre-commit shows hook output
  on failure (and always when `verbose: true`). A good guard prints *why* it
  failed and *how to fix it* (this repo's hooks emit a remediation recipe to
  stderr).
- **Determinism & idempotency:** the same staged input must yield the same
  result; running a fixer twice must be a no-op the second time. Non-deterministic
  hooks erode trust and cause spurious diffs.
- **Tunability:** expose behaviour through `args` parsed defensively with a sane
  default, never a hard-coded org-specific value a consumer can't override (e.g.
  `--maxkb`, `--branch`). Consumers set `args:` in their config.
- **fail-open vs fail-closed:** decide deliberately. A guard that targets a
  developer's local `git commit` should **fail open in automation** (short-circuit
  to exit 0 when `CI` is set), because CI checks the branch out in a detached HEAD
  inside a normal clone where the guard's premise no longer holds — otherwise it
  blocks every lint job. Correctness/security checks intended to gate everywhere
  should fail closed. (This repo's contract: hooks fail open under `CI`.)

## 7. Performance

- **Parallelism:** since pre-commit 1.13.0, pre-commit splits *one hook's* file
  list across multiple processes and runs them in parallel. This is per-hook file
  batching — **not** running distinct hooks concurrently.
- **`require_serial: true`** forces a single process. Required for any hook that
  touches **shared resources outside the passed files** (reads shared config,
  writes a shared log, mutates a single output file) to avoid races/deadlocks
  across the parallel workers. The default (parallel) trades that safety for speed.
- **File filtering is the primary performance lever:** narrow `types`/`files` so
  the hook is invoked on as few files as possible.
- **Latency budget:** keep total local pre-commit runtime **under ~5 seconds**;
  beyond that developers start reaching for `--no-verify`, defeating the hooks. A
  rule of thumb from practitioners: a check that takes >5s **and** fails on <~10%
  of commits belongs in **CI only**, not local hooks. Fast formatters (e.g.
  `black`, `ruff`) run well locally; slow validators (full `mypy`, full test
  suites) belong in CI. Test hooks scoped to changed files only can cut local time
  dramatically (reported 47s → 3–8s) while the full suite stays a CI concern.

## 8. Building and distributing a reusable hook repository

- **The hook scripts + `.pre-commit-hooks.yaml` are the product.** There is no
  build artifact for `script`/`pygrep`/`fail` hooks.
- For a **Python** hook the recipe is: (1) a check function (accepts filename(s),
  returns bool/int, `0` = ok); (2) a CLI wrapper (e.g. `argparse`); (3) make it
  installable via `pyproject.toml` entry-point `scripts`/`console_scripts`; (4)
  the `.pre-commit-hooks.yaml` manifest whose `entry` is that console script.
- **Consumption:** consumers add a `repos:` entry pointing at the repo URL, pinned
  to a `rev`, and select hooks by `id`:

  ```yaml
  repos:
    - repo: https://github.com/<org>/<repo>
      rev: v1.0.0
      hooks:
        - id: <hook-id>
          args: [--branch=main]
  ```

- **Versioning / `rev`:**
  - Pin to an **immutable** ref. A git **tag containing a dot** (e.g. `v1.2.0`) is
    what `pre-commit autoupdate` prefers when bumping.
  - **A branch name or `HEAD` is unsupported as `rev`** — it captures only the
    state at install time and will not auto-update.
  - `pre-commit autoupdate` rewrites each `rev` to the latest tag; with
    `--freeze` it writes a commit **SHA** (annotated with the tag). Note: `--freeze`
    still resolves to the *latest* revision — it does not preserve an
    already-pinned SHA. There is **no built-in way to lock a `rev`** against
    autoupdate; the only mechanism is operational (don't run autoupdate, or run it
    deliberately and review the diff).
- **Pre-publish validation:** test the hook against a sample repo with
  `pre-commit try-repo <path-or-url> <hook-id>` before tagging a release; create
  the release tag with `git tag -a <version>`.

## 9. Testing strategy

- **Throwaway-repo integration tests** (this repo's pattern): build a sandbox git
  repo, drive `HEAD`/the index into a known state, run the hook, assert on the
  **exit code**. Cover the pass case, the fail case, every `args` branch, the
  fail-open (`CI`) path, and edge states (detached HEAD, worktrees). No network,
  no global git-config side effects.
- **`pre-commit try-repo`** for a real end-to-end run through the framework.
- For Python hooks, unit-test the check function directly with `pytest`.
- Run `pre-commit validate-manifest` in CI to catch manifest regressions.

## 10. Anti-patterns

- **Reading the working tree instead of the staged index.** A fix present only in
  the working tree (unstaged) lets the hook pass while the committed/index content
  is still broken — a real correctness bug. Operate on what pre-commit provides.
- **Auto-modifying the commit during the run** so the pushed result diverges from
  what was reviewed. Mutating fixers are acceptable *because they fail the run and
  force a re-stage*; silently rewriting the commit content is not.
- **Slow hooks on every commit.** They interfere with rebase/amend workflows and
  push developers to `--no-verify`. Move them to `pre-push`, `manual`, or CI.
- **Hooks with shared mutable state but no `require_serial`** → races under the
  default parallelism.
- **Hard-coding org-specific values** that a consuming repo can't override; expose
  them via `args` with defaults instead.
- **Treating local hooks as enforcement.** `--no-verify` bypasses them; the same
  check must exist in CI to actually gate.

## 11. Security and supply chain

Hooks execute **arbitrary code on every commit** once a developer runs
`pre-commit install`. This makes hook repositories a supply-chain surface:

- **A single poisoned commit in a shared repo compromises every developer who
  clones it and installs the hooks** — e.g. a hook entry running a reverse-shell
  payload yields code execution on the developer's machine. Backdated commit
  timestamps can disguise the change.
- **Mutable-tag risk:** pinning a third-party repo to a `rev` *tag* is not
  sufficient against a determined attacker, because a tag can be force-repushed to
  point at malicious code without any change to the config. **Hardening:** pin
  third-party hooks to an **immutable full commit SHA**, annotated with the
  human-readable version, e.g.
  `rev: ce40a160603ab0e7d9c627ae33d7ef3906e2d2b2 # frozen: v3.19.1`. Produce these
  pins with `pre-commit autoupdate --freeze`. *(The pre-commit maintainer disputes
  framing `--freeze` as a security feature; treat SHA-pinning as defence-in-depth
  the consumer chooses, not a guarantee the framework provides.)*
- **CVE-2025-62726** (CVSS 8.8, High): pre-commit hooks delivered via a cloned
  remote repository are a real-world remote-code-execution vector — committing
  hook code that runs automatically on the next git operation. Mitigations: don't
  run hooks from untrusted repositories; never run hooks as **root** (root
  execution hands the attacker the whole machine).

**What a hook should not do:** run untrusted input through a shell without
quoting; assume `args`/filenames are safe (paths can contain spaces/newlines —
quote everything; `set -euo pipefail` for shell hooks); require network access or
elevated privileges; or perform side effects beyond the check it advertises.

## 12. Targeting checklist (reference)

When the goal is *one* targeted hook, the design decisions in order:

1. **What git event's content does the check need?** → pick the `stages` value
   (`pre-commit` / `commit-msg` / `pre-push` / `manual`).
2. **Per-file or whole-repo?** → set `pass_filenames` (and `always_run` for
   whole-repo).
3. **Which files?** → narrow with `types`/`types_or`/`files`/`exclude` (verify
   with `identify-cli`).
4. **What runtime does it need?** → choose the lightest `language`
   (`pygrep`/`fail` → `script`/`system` → managed `python`/`node`/… → `docker`).
5. **Checker or fixer?** → checker reports only; fixer mutates and fails the run.
6. **What's configurable?** → expose via `args` with safe defaults.
7. **Where must it actually gate?** → fail open locally / enforce in CI as
   appropriate; decide fail-open vs fail-closed deliberately.
8. **Shared state?** → set `require_serial` if it touches resources outside the
   passed files.
9. **Tests:** sandbox repo asserting exit codes for every branch, plus
   `validate-manifest` and `try-repo`.

## Sources

Primary (official / canonical):

- pre-commit.com — main docs, "Creating new hooks", filtering, `rev` semantics:
  <https://pre-commit.com/>
- Supported hooks listing: <https://pre-commit.com/hooks.html>
- `pre-commit/pre-commit-hooks` manifest (canonical hook examples):
  <https://github.com/pre-commit/pre-commit-hooks/blob/main/.pre-commit-hooks.yaml>
- `pre-commit/pre-commit` own manifest (`validate_manifest`):
  <https://github.com/pre-commit/pre-commit/blob/main/.pre-commit-hooks.yaml>
- `identify` library (file type tags): <https://github.com/pre-commit/identify>
- pre-commit advanced docs (stages/filtering):
  <https://github.com/pre-commit/pre-commit.com/blob/main/sections/advanced.md>
- git `githooks` reference / Pro Git "Git Hooks":
  <https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks>
- `--all-files` does not bypass filters (maintainer):
  <https://github.com/pre-commit/pre-commit/issues/3309>
- `rev` freezing / no built-in lock (maintainer):
  <https://github.com/pre-commit/pre-commit/issues/3066>

Secondary (practitioner / security):

- Stefanie Molin, "Creating a Custom pre-commit Hook":
  <https://stefaniemolin.com/articles/devx/pre-commit/hook-creation-guide/>
- "pre-commit hooks vs CI — when to skip local checks":
  <https://tildalice.io/pre-commit-hooks-vs-ci-when-to-skip-local-checks/>
- Working-tree-vs-index / auto-modify discussion (lobste.rs):
  <https://lobste.rs/s/pjysyq/pre_commit_hooks_are_fundamentally>
- Supply-chain demonstration:
  <https://medium.com/@3wisesiren/exploiting-pre-commit-hooks-a-practical-demonstration-4c4bcefe32c8>
- CVE-2025-62726 advisory (RCE via cloned-repo hooks, CVSS 8.8):
  <https://github.com/n8n-io/n8n/security/advisories/GHSA-xgp7-7qjq-vg47>

> Research provenance: 6 search angles, 19 sources fetched, 87 claims extracted,
> 25 adversarially verified (24 confirmed, 1 refuted). The refuted claim asserted
> `description` is a *required* manifest field; it is optional (default `''`) —
> corrected in [§2](#2-the-manifest-pre-commit-hooksyaml).
