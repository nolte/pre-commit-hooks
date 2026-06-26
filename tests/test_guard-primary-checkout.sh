#!/usr/bin/env bash
# Self-test for hooks/guard-primary-checkout.sh.
#
# Each case builds a throwaway git repo under tests/.sandbox/, drives HEAD into
# a known state, runs the hook, and asserts on its exit code. No network, no
# global git config side effects.
#
# Run: tests/test_guard-primary-checkout.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
repo_root="$(cd "$here/.." && pwd -P)"
hook="$repo_root/hooks/guard-primary-checkout.sh"
sandbox="$here/.sandbox"

rm -rf "$sandbox"
mkdir -p "$sandbox"
trap 'rm -rf "$sandbox"' EXIT

pass=0
fail=0
check() { # <description> <expected-exit> <actual-exit>
  if [ "$2" = "$3" ]; then
    echo "✓ $1"
    pass=$((pass + 1))
  else
    echo "✗ $1 (expected exit $2, got $3)"
    fail=$((fail + 1))
  fi
}

# A fresh repo whose default branch is the given integration branch, with one
# commit so HEAD is a real ref.
new_repo() { # <dir> <integration-branch>
  local dir="$1" branch="$2"
  git init -q -b "$branch" "$dir"
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

run_hook() { # runs the hook inside $1, with remaining args forwarded; echoes exit code
  local dir="$1"; shift
  ( cd "$dir" && CI= "$hook" "$@" >/dev/null 2>&1; echo "$?" )
}

# 1. Primary checkout on develop → allowed.
new_repo "$sandbox/r1" develop
check "primary on develop is allowed" 0 "$(run_hook "$sandbox/r1")"

# 2. Primary checkout on a feature branch → blocked.
new_repo "$sandbox/r2" develop
git -C "$sandbox/r2" switch -q -c feat/x
check "primary on feature branch is blocked" 1 "$(run_hook "$sandbox/r2")"

# 3. --branch=main: primary on main → allowed.
new_repo "$sandbox/r3" main
check "primary on main allowed with --branch=main" 0 "$(run_hook "$sandbox/r3" --branch=main)"

# 4. --branch=main: primary on develop → blocked (develop is not the configured branch).
new_repo "$sandbox/r4" develop
check "develop blocked when integration branch is main" 1 "$(run_hook "$sandbox/r4" --branch=main)"

# 5. Linked worktree on a feature branch → allowed (feature work belongs here).
new_repo "$sandbox/r5" develop
git -C "$sandbox/r5" worktree add -q -b feat/y "$sandbox/r5-wt" >/dev/null 2>&1
check "feature branch in linked worktree is allowed" 0 "$(run_hook "$sandbox/r5-wt")"

# 6. CI=1 short-circuits to allow even on a feature branch.
new_repo "$sandbox/r6" develop
git -C "$sandbox/r6" switch -q -c feat/z
check "CI short-circuits to allow" 0 "$( cd "$sandbox/r6" && CI=1 "$hook" >/dev/null 2>&1; echo "$?" )"

echo
echo "Passed: $pass  Failed: $fail"
[ "$fail" -eq 0 ]
