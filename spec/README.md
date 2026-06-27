# spec/

Requirements, NFRs, and domain knowledge for this repository.

## Domain knowledge

- [`hook-authoring/`](hook-authoring/en.md) ([de](hook-authoring/de.md)) — the
  reference knowledge base for designing, building, distributing, and securing
  reusable pre-commit hooks (manifest fields, language backends, stages, file
  targeting, the hook contract, performance, anti-patterns, supply-chain
  security). Intended as the foundation a skill consults when developing a
  *targeted* hook. Canonical language: English.

## Per-hook requirements

The hooks shipped here operationalise portfolio-wide specifications that live
in [`nolte/claude-shared`](https://github.com/nolte/claude-shared) rather than
being restated per repository:

- `guard-primary-checkout` enforces `spec/project/parallel-working-copies/`
  §Branch-to-worktree mapping (the primary checkout stays on its integration
  branch; feature work happens in a dedicated worktree) and the branch-prefix
  rule from `spec/project/branching-model/`.

When a hook grows its own repository-specific requirements that are not owned
by a portfolio spec, capture them here as `<topic>/<lang>.md` following the
multilingual spec convention.
