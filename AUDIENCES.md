# Audiences—nolte/pre-commit-hooks

<!--
Produced via the `audience-identify` skill, following
spec/project/audience-identification/.
Do not add audiences without first declaring the bounded context below.
-->

## Bounded context

- `nolte/pre-commit-hooks` is a collection of reusable pre-commit hook scripts
  (`hooks/<id>.sh`, exposed through `.pre-commit-hooks.yaml`). The scripts
  themselves are the product—there is no build artifact.
- Downstream repositories of the nolte portfolio consume the hooks remotely via
  pre-commit's `repos:` mechanism, pinned to a release tag.
- Out of scope: the code and content of the consumer repositories; the portfolio
  CI infrastructure itself; the upstream presets (`nolte/gh-plumbing`,
  `nolte/taskfiles`) that this repository only *consumes*.

## Audiences

Each entry: label, relationship category, interaction surface, expectation,
documentation `track` (`user-docs` or `developer-docs` per
spec/project/docs-audience-tracks/), open questions, `confirmed` or `assumed`,
criticality (primary / secondary / peripheral).

Portfolio-baseline track defaults: `user` → `user-docs`; `contributor` /
`operator` / `release-manager` → `developer-docs`. Every audience below maps to
`developer-docs`: this repository is developer tooling with no end-user runtime
surface. See the explicit track-omission note under "Direct consumers" for the
absent `user-docs` track.

### Direct consumers

> no audience maps to this track: `user-docs`—pre-commit-hooks is developer-only
> tooling consumed by other repositories' commit pipelines; it has no end-user
> runtime surface, so no audience belongs to the `user-docs` track.

- **hook-consumer-project**—_category_: direct-consumer · _surface_:
  `.pre-commit-config.yaml` wiring + `.pre-commit-hooks.yaml` manifest + released
  tags · _expects_: stable hook IDs, semver-pinned tags, documented `args` ·
  _track_: `developer-docs` · _status_: `assumed` · _criticality_: primary
  - Open questions: none
- **consumer-developer**—_category_: direct-consumer · _surface_: CLI
  (`git commit` / `pre-commit run`), hook output messages · _expects_: clear
  failure messages, configurable `args`, an escape hatch when a guard fires
  intentionally · _track_: `developer-docs` · _status_: `assumed` ·
  _criticality_: primary
  - Open questions: none

### Operators

- **consumer-ci**—_category_: operator · _surface_: CI environment (the `CI`
  env var fail-open behaviour), hook exit codes · _expects_: fail-open under
  `CI` so the same hook installed locally doesn't block CI lint jobs;
  deterministic exit codes · _track_: `developer-docs` · _status_: `assumed` ·
  _criticality_: secondary
  - Open questions: none

### Contributors / maintainers

- **hook-maintainer**—_category_: contributor · _surface_: `hooks/`, `tests/`,
  `.pre-commit-hooks.yaml`, `CLAUDE.md` · _expects_: the hook-authoring
  conventions and the self-test contract (one `tests/test_<id>.sh` per hook) ·
  _track_: `developer-docs` · _status_: `assumed` · _criticality_: primary
  - Note: this audience also covers the portfolio-baseline `release-manager`
    role—the maintainer who triggers the `release-publish` workflow—folded in
    rather than split out, since the release surface is maintainer-operated and
    has no distinct consumer.
  - Open questions: none
- **documentation-author**—_category_: contributor · _surface_: `docs/`,
  `mkdocs.yml`, Vale config · _expects_: the mkdocs structure conventions and the
  strict-build documentation gate · _track_: `developer-docs` · _status_:
  `assumed` · _criticality_: secondary
  - Open questions: none

### Governing parties

- **portfolio-conventions**—_category_: governing-party · _surface_: `spec/`
  references, `.github/settings.yml` `_extends`, the release-management workflows ·
  _expects_: conformance to the portfolio project-structure and branching-model
  conventions · _track_: `developer-docs` · _status_: `assumed` · _criticality_:
  secondary
  - Open questions: none
- **renovate-governance**—_category_: governing-party · _surface_:
  `renovate.json5`, the shared `nolte/gh-plumbing` preset, the Renovate
  Dependency Dashboard · _expects_: the pinned portfolio preset and automated
  dependency-update PRs landing without per-repo configuration drift · _track_:
  `developer-docs` · _status_: `assumed` · _criticality_: peripheral
  - Open questions: none

### Indirect audiences

- none—pre-commit-hooks is developer tooling; no end-user or third party
  experiences the hooks in a material indirect way. The guarded behaviour stays
  inside the commit pipeline of the consumer developer and CI.

## Open questions (cross-cutting)

- All entries are `assumed`: no audience has yet been validated with a real
  representative or an authoritative source. Promote to `confirmed` once
  validated.

## Revisit triggers

- A new hook ships that targets a different consumer surface (for example a hook
  meant to run in CI only, not on local commits).
- The repository starts producing a delivery artifact (it currently ships none),
  which would introduce an end-user / release-consumer surface and a `user-docs`
  track.
- A new regulated or governance surface is added (for example a security or
  license-compliance governing party).
- The hooks gain configuration consumed by a non-developer role.
