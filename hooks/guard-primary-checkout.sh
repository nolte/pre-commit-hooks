#!/usr/bin/env bash
# Guard: the primary checkout MUST stay on its integration branch.
#
# Consumed as the `guard-primary-checkout` pre-commit hook (always_run,
# pass_filenames: false), so it fires on every `git commit`.
#
# It enforces a parallel-working-copies model: the primary checkout is for
# integration only and stays on the integration branch (default `develop`)
# at all times; every change happens on a feature branch inside a dedicated
# git worktree. This hook closes the most common failure mode — committing
# feature work directly in the primary checkout.
#
# The integration branch is configurable via `--branch <name>` (pre-commit
# `args:`), so a repository that integrates on `main` is supported too.
#
# Self-detection: the hook is installed once in the shared hooks dir and
# therefore also fires inside linked worktrees. Worktrees are the *correct*
# place for feature-branch commits, so the guard exits 0 in any linked
# worktree and only enforces the rule in the primary checkout, distinguished
# by git-dir == git-common-dir.
set -euo pipefail

integration_branch="develop"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --branch) integration_branch="${2:?--branch needs a value}"; shift 2 ;;
    --branch=*) integration_branch="${1#*=}"; shift ;;
    --) shift; break ;;
    *) shift ;;  # ignore filenames or unknown args; this hook is path-agnostic
  esac
done

# Skip in CI and other non-interactive automation. CI runners (and
# `pre-commit run --all-files`) check the branch out in a detached HEAD inside
# a normal clone, where git-dir == git-common-dir — indistinguishable from a
# primary checkout sitting on a feature branch, so the guard would block the
# lint job on every feature-branch PR. This guard targets a developer's local
# `git commit`, not CI; `CI` is set by GitHub Actions and essentially every
# other CI provider.
if [ -n "${CI:-}" ]; then
  exit 0
fi

# Resolve both to absolute paths. In the primary checkout the per-worktree
# git-dir and the shared git-common-dir are the same directory; in a linked
# worktree the git-dir is .git/worktrees/<name> and they differ.
git_dir="$(cd "$(git rev-parse --git-dir)" && pwd -P)"
common_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)"

if [ "$git_dir" != "$common_dir" ]; then
  # Linked worktree — feature-branch commits belong here. Nothing to enforce.
  exit 0
fi

# Primary checkout: it MUST be on the integration branch.
branch="$(git symbolic-ref --quiet --short HEAD || true)"

if [ "$branch" = "$integration_branch" ]; then
  exit 0
fi

if [ -z "$branch" ]; then
  state="a detached HEAD"
else
  state="branch '$branch'"
fi

cat >&2 <<EOF
✖ Primary checkout is on $state, not '$integration_branch' — commit blocked.

  The primary checkout ($(pwd -P)) is for integration only and MUST stay
  on '$integration_branch' at all times. Feature work happens on a feature
  branch in a dedicated worktree that branches off '$integration_branch'.

  Repair the drift instead of committing here:

    # 1. park the current feature work in its own worktree
    git switch $integration_branch
    git worktree add ../<worktree-dir> $branch
    #    (or, for a fresh branch: task worktree:add -- $branch)

    # 2. restore the primary checkout to the remote tip
    git fetch origin $integration_branch && git merge --ff-only origin/$integration_branch

  Then re-run your commit from inside the worktree.
EOF
exit 1
