# spec/

Requirements, NFRs, and domain knowledge for this repository.

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
