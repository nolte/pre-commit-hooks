#!/usr/bin/env bash
# Self-test for hooks/guard-spec-translation-sync.sh.
#
# Each case builds a throwaway git repo under tests/.sandbox/, stages a known
# set of spec files, runs the hook, and asserts on its exit code. No network, no
# global git config side effects.
#
# Run: tests/test_guard-spec-translation-sync.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
repo_root="$(cd "$here/.." && pwd -P)"
hook="$repo_root/hooks/guard-spec-translation-sync.sh"
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

# A fresh repo with an initial commit so HEAD exists.
new_repo() { # <dir>
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

# Write a file, creating parent dirs.
put() { # <dir> <relpath> <content>
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}

# Commit a tracked translation pair so HEAD has both languages.
seed_pair() { # <dir> <topic>
  local dir="$1" topic="$2"
  put "$dir" "spec/$topic/en.md" "en v1"
  put "$dir" "spec/$topic/de.md" "de v1"
  git -C "$dir" add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m "seed $topic"
}

run_hook() { # <dir> [args…]; echoes exit code
  local dir="$1"; shift
  # `env -u CI` removes CI from the environment so the hook's CI short-circuit
  # does not fire — these cases assert the real staged-pair enforcement.
  ( cd "$dir" && env -u CI "$hook" "$@" >/dev/null 2>&1; echo "$?" )
}

# 1. Both translations staged together → allowed.
new_repo "$sandbox/r1"; seed_pair "$sandbox/r1" topic
put "$sandbox/r1" spec/topic/en.md "en v2"
put "$sandbox/r1" spec/topic/de.md "de v2"
git -C "$sandbox/r1" add -A
check "both translations staged together is allowed" 0 "$(run_hook "$sandbox/r1")"

# 2. Only the canonical en.md staged, de.md tracked but untouched → blocked.
new_repo "$sandbox/r2"; seed_pair "$sandbox/r2" topic
put "$sandbox/r2" spec/topic/en.md "en v2"
git -C "$sandbox/r2" add spec/topic/en.md
check "staging only en while de is tracked is blocked" 1 "$(run_hook "$sandbox/r2")"

# 3. Only the translation de.md staged, en.md tracked but untouched → blocked.
new_repo "$sandbox/r3"; seed_pair "$sandbox/r3" topic
put "$sandbox/r3" spec/topic/de.md "de v2"
git -C "$sandbox/r3" add spec/topic/de.md
check "staging only de while en is tracked is blocked" 1 "$(run_hook "$sandbox/r3")"

# 4. A brand-new topic with only en.md (no tracked sibling) → allowed.
new_repo "$sandbox/r4"
put "$sandbox/r4" spec/fresh/en.md "en new"
git -C "$sandbox/r4" add spec/fresh/en.md
check "brand-new topic with only en is allowed" 0 "$(run_hook "$sandbox/r4")"

# 5. Unrelated staged file (spec/README.md, no <lang> segment) → allowed.
new_repo "$sandbox/r5"; seed_pair "$sandbox/r5" topic
put "$sandbox/r5" spec/README.md "index"
git -C "$sandbox/r5" add spec/README.md
check "unrelated spec/README.md is allowed" 0 "$(run_hook "$sandbox/r5")"

# 6. --lang restricted to en: staging only en does not require de → allowed.
new_repo "$sandbox/r6"; seed_pair "$sandbox/r6" topic
put "$sandbox/r6" spec/topic/en.md "en v2"
git -C "$sandbox/r6" add spec/topic/en.md
check "single configured language never blocks" 0 "$(run_hook "$sandbox/r6" --lang=en)"

# 7. Three configured languages: en+de staged, fr tracked and unstaged → blocked.
new_repo "$sandbox/r7"; seed_pair "$sandbox/r7" topic
put "$sandbox/r7" spec/topic/fr.md "fr v1"
git -C "$sandbox/r7" add spec/topic/fr.md
git -C "$sandbox/r7" -c user.email=t@t -c user.name=t commit -q -m "add fr"
put "$sandbox/r7" spec/topic/en.md "en v2"
put "$sandbox/r7" spec/topic/de.md "de v2"
git -C "$sandbox/r7" add spec/topic/en.md spec/topic/de.md
check "third tracked language left unstaged is blocked" 1 "$(run_hook "$sandbox/r7" --lang=en --lang=de --lang=fr)"

# 8. Custom --spec-dir: pair under specs/ staged together → allowed.
new_repo "$sandbox/r8"
put "$sandbox/r8" specs/topic/en.md "en v1"
put "$sandbox/r8" specs/topic/de.md "de v1"
git -C "$sandbox/r8" add -A
git -C "$sandbox/r8" -c user.email=t@t -c user.name=t commit -q -m "seed"
put "$sandbox/r8" specs/topic/en.md "en v2"
git -C "$sandbox/r8" add specs/topic/en.md
check "custom --spec-dir blocks a half-staged pair" 1 "$(run_hook "$sandbox/r8" --spec-dir=specs)"

# 9. CI=1 short-circuits to allow even with a half-staged pair.
new_repo "$sandbox/r9"; seed_pair "$sandbox/r9" topic
put "$sandbox/r9" spec/topic/en.md "en v2"
git -C "$sandbox/r9" add spec/topic/en.md
check "CI short-circuits to allow" 0 "$( cd "$sandbox/r9" && CI=1 "$hook" >/dev/null 2>&1; echo "$?" )"

# 10. Nothing staged at all → allowed.
new_repo "$sandbox/r10"; seed_pair "$sandbox/r10" topic
check "no staged files is allowed" 0 "$(run_hook "$sandbox/r10")"

# 11. Non-ASCII topic dir: only en.md staged, de.md tracked → blocked. Guards
#     against git C-quoting non-ASCII paths in `diff --cached --name-only`, which
#     would otherwise make the path unmatchable and let the pair slip through.
new_repo "$sandbox/r11"; seed_pair "$sandbox/r11" "größe"
put "$sandbox/r11" "spec/größe/en.md" "en v2"
git -C "$sandbox/r11" add "spec/größe/en.md"
check "non-ASCII topic dir is still guarded" 1 "$(run_hook "$sandbox/r11")"

# 12. Trailing slash in --spec-dir is normalised (still blocks a half-staged pair).
new_repo "$sandbox/r12"; seed_pair "$sandbox/r12" topic
put "$sandbox/r12" spec/topic/en.md "en v2"
git -C "$sandbox/r12" add spec/topic/en.md
check "trailing-slash --spec-dir is normalised" 1 "$(run_hook "$sandbox/r12" --spec-dir=spec/)"

echo
echo "Passed: $pass  Failed: $fail"
[ "$fail" -eq 0 ]
