#!/usr/bin/env bash
# Guard: a spec topic's canonical and translated files must be staged together.
#
# Consumed as the `guard-spec-translation-sync` pre-commit hook with
# `pass_filenames: false`, so it inspects the staged set itself via
# `git diff --cached` rather than a filtered file list. That is deliberate: with
# per-hook file lists pre-commit may batch a sibling pair (en.md / de.md) across
# parallel processes, so a single process could see one half without the other
# and raise a false positive. Reading the whole staged set once avoids that
# (see spec/hook-authoring/en.md §5 and §7).
#
# The nolte multilingual spec convention (spec/README.md) keeps every
# spec/<topic>/<lang>.md in lockstep: one canonical language, the rest strict
# translations. This hook enforces that at commit time — if any configured
# <lang>.md of a topic is staged, every configured language whose file is tracked
# in HEAD for that topic must be staged too.
#
# Configure the languages with repeated `--lang` args (default `en de`) and the
# spec root with `--spec-dir` (default `spec`), via pre-commit `args:`.
set -euo pipefail

spec_dir="spec"
langs=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --spec-dir) spec_dir="${2:?--spec-dir needs a value}"; shift 2 ;;
    --spec-dir=*) spec_dir="${1#*=}"; shift ;;
    --lang) langs+=("${2:?--lang needs a value}"); shift 2 ;;
    --lang=*) langs+=("${1#*=}"); shift ;;
    --) shift; break ;;
    *) shift ;;  # ignore filenames or unknown args; this hook is path-agnostic
  esac
done
# Default language set when none configured.
if [ "${#langs[@]}" -eq 0 ]; then
  langs=(en de)
fi
# Normalise a trailing slash so `--spec-dir spec/` matches like `--spec-dir spec`.
spec_dir="${spec_dir%/}"

# Fail open in CI and other non-interactive automation. CI runs
# `pre-commit run --all-files`, where there is no staged set (`git diff --cached`
# is empty) and this guard's premise — a developer staging only part of a
# translation pair — does not hold. The same hook installed locally still
# enforces the rule. (Repo contract; spec/hook-authoring/en.md §6.)
if [ -n "${CI:-}" ]; then
  exit 0
fi

# The paths staged for this commit (added/copied/modified/renamed), read
# NUL-delimited into an array. `git diff --name-only -z` emits raw, unquoted,
# NUL-terminated paths; without -z git C-quotes any path with non-ASCII bytes
# (e.g. `spec/größe/en.md`) into a `"..."` form that the matching below would
# miss — silently letting a half-staged pair through.
staged=()
while IFS= read -r -d '' path; do
  staged+=("$path")
done < <(git diff --cached --name-only -z --diff-filter=ACMR)
[ "${#staged[@]}" -eq 0 ] && exit 0

in_array() { # <needle> [element…]; true when needle equals one element
  local needle="$1"; shift
  local element
  for element in "$@"; do
    [ "$element" = "$needle" ] && return 0
  done
  return 1
}
is_staged() { in_array "$1" ${staged[@]+"${staged[@]}"}; }
# A language file is "in play" for a topic when it is tracked in HEAD; a tracked
# sibling that is not staged is the drift. A brand-new topic (no HEAD entry yet)
# is not blocked.
tracked_in_head() { git cat-file -e "HEAD:$1" 2>/dev/null; }

# Collect the unique topics that have at least one staged configured <lang>.md,
# where a topic is the single path segment in spec/<topic>/<lang>.md.
topics=()
for path in "${staged[@]}"; do
  case "$path" in
    "$spec_dir"/*/*.md) ;;
    *) continue ;;
  esac
  rest="${path#"$spec_dir"/}"   # <topic>/<lang>.md (or deeper)
  case "$rest" in */*/*) continue ;; esac   # reject nesting below <topic>/
  topic="${rest%%/*}"
  lang="${rest#*/}"; lang="${lang%.md}"
  in_array "$lang" "${langs[@]}" || continue
  in_array "$topic" ${topics[@]+"${topics[@]}"} || topics+=("$topic")
done
[ "${#topics[@]}" -eq 0 ] && exit 0

missing=()
for topic in "${topics[@]}"; do
  for lang in "${langs[@]}"; do
    file="${spec_dir}/${topic}/${lang}.md"
    is_staged "$file" && continue
    tracked_in_head "$file" && missing+=("$file")
  done
done

if [ "${#missing[@]}" -eq 0 ]; then
  exit 0
fi

{
  printf '✖ Spec translations out of sync — commit blocked.\n\n'
  printf '  The nolte spec convention keeps every spec/<topic>/<lang>.md in\n'
  printf '  lockstep. You staged one language of a topic but left its tracked\n'
  printf '  sibling translation(s) unstaged:\n\n'
  for file in "${missing[@]}"; do
    printf '    %s\n' "$file"
  done
  printf '\n  Stage the matching translation(s) so each topic moves as a set —\n'
  printf '  edit the canonical language first and propagate. A deliberate\n'
  printf '  work-in-progress can bypass with: git commit --no-verify\n'
} >&2
exit 1
