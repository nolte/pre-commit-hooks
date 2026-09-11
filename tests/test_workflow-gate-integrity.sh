#!/usr/bin/env bash
# Self-test for hooks/workflow-gate-integrity.py.
#
# Each case builds a throwaway git repo under tests/.sandbox/, runs the hook
# over it, and asserts on the findings. No network, no global git config side
# effects.
#
# Two of the cases are FALSIFICATION cases required by nolte/pre-commit-hooks#11:
# they restore the pre-fix state of a real, closed kamerplanter defect and
# require the hook to be red on it. A hook that is green in its origin
# repository and has never been red in this one is not verified, it is
# installed.
#
# Those two assert on the FILE, LINE and KIND of the finding, never on the exit
# code alone. The exit code is the wrong assertion here and the trap is not
# hypothetical: running the hook over the whole pre-fix tree of one of these
# defects exits 1 on seven unrelated pre-existing findings in another workflow,
# so an exit-code assertion passes while proving nothing about the defect it
# names — and keeps passing after the hook loses the ability to detect it.
#
# Run: tests/test_workflow-gate-integrity.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
repo_root="$(cd "$here/.." && pwd -P)"
hook="$repo_root/hooks/workflow-gate-integrity.py"
fixtures="$here/fixtures/workflow-gate-integrity"
sandbox="$here/.sandbox"

rm -rf "$sandbox"
mkdir -p "$sandbox"
trap 'rm -rf "$sandbox"' EXIT

pass=0
fail=0
check() { # <description> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "✓ $1"
    pass=$((pass + 1))
  else
    echo "✗ $1"
    echo "    expected: $2"
    echo "    actual:   $3"
    fail=$((fail + 1))
  fi
}

if ! python3 -c 'import yaml' >/dev/null 2>&1; then
  echo "PyYAML is not installed; the hook cannot run. Install it:" >&2
  echo "    python3 -m pip install PyYAML" >&2
  exit 2
fi

# A throwaway repo whose tracked content is the fixture variant. The content
# must be COMMITTED: the fifth shape resolves read paths against the tracked
# files of the checkout, so an uncommitted tree would silently change verdicts.
new_repo() { # <dir> <source-tree>
  local dir="$1" src="$2"
  rm -rf "$dir"
  mkdir -p "$dir"
  cp -R "$src/." "$dir/"
  git init -q -b main "$dir"
  git -C "$dir" -c user.email=t@t -c user.name=t add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m fixture
}

# Every unjustified finding for one workflow, as "<basename>:<line>:<kind>"
# lines, sorted. Empty output means the hook reported nothing for that file.
#
# A failure to produce that list echoes ERROR rather than nothing. An empty
# string is a meaningful expected value here (it is how the post-fix cases
# assert "green"), so a helper that returned empty on a crash would make those
# cases pass without running the hook at all — the defect class this hook is
# about, reproduced in its own test.
findings_for() { # <repo-dir> <workflow-basename>
  local dir="$1" want="$2" json rows
  if ! json="$( cd "$dir" && python3 "$hook" --scan-root .github/workflows --tree-root . --json 2>/dev/null )"; then
    case "$( cd "$dir" && python3 "$hook" --scan-root .github/workflows --tree-root . --json >/dev/null 2>&1; echo $? )" in
      1) : ;;                       # findings present; --json still printed them
      *) echo "ERROR: the hook did not run"; return 0 ;;
    esac
  fi
  if ! rows="$( printf '%s' "$json" | WANT="$want" python3 -c '
import json, os, sys
want = os.environ["WANT"]
document = json.load(sys.stdin)
rows = []
for finding in document["unjustified"]:
    name = os.path.basename(finding["file"])
    if name == want:
        rows.append("%s:%s:%s" % (name, finding["line"], finding["kind"]))
sys.stdout.write("\n".join(sorted(rows)))
' 2>/dev/null )"; then
    echo "ERROR: the hook produced no parseable JSON"
    return 0
  fi
  printf '%s' "$rows"
}

exit_of() { # <repo-dir> [args...]  — echoes the hook's exit code
  local dir="$1"; shift
  ( cd "$dir" && python3 "$hook" "$@" >/dev/null 2>&1; echo "$?" )
}

# --- Falsification 1: kamerplanter#1302 -------------------------------------
# A pin assertion whose own paths: filter excludes the pin file it reads.
f="$fixtures/1302-uncovered-path"
new_repo "$sandbox/f1302-red" "$f/red"
check "kamerplanter#1302 pre-fix state is RED on the named defect" \
  "security-nuclei-templates.yml:74:uncovered_path_reference" \
  "$(findings_for "$sandbox/f1302-red" security-nuclei-templates.yml)"

new_repo "$sandbox/f1302-green" "$f/green"
check "kamerplanter#1302 post-fix state is GREEN on that file" \
  "" \
  "$(findings_for "$sandbox/f1302-green" security-nuclei-templates.yml)"

# --- Falsification 2: kamerplanter#1294 -------------------------------------
# A comment block after a trailing backslash truncates the scan command, so the
# artefacts later steps gate on are never written. Stands in for #1235, whose
# defect lived outside .github/workflows entirely — see the fixture PROVENANCE.
f="$fixtures/1294-commented-continuation"
new_repo "$sandbox/f1294-red" "$f/red"
check "kamerplanter#1294 pre-fix state is RED on the named defect" \
  "security-nuclei-nightly.yml:190:commented_continuation" \
  "$(findings_for "$sandbox/f1294-red" security-nuclei-nightly.yml)"

new_repo "$sandbox/f1294-green" "$f/green"
check "kamerplanter#1294 post-fix state is GREEN on that file" \
  "" \
  "$(findings_for "$sandbox/f1294-green" security-nuclei-nightly.yml)"

# --- Synthetic shapes and the contract --------------------------------------
mk() { # <dir> <workflow-body> [extra-tracked-path ...]
  local dir="$1"; shift
  local body="$1"; shift
  rm -rf "$dir"; mkdir -p "$dir/.github/workflows"
  printf '%s\n' "$body" > "$dir/.github/workflows/w.yml"
  # Extra tracked files, committed with the workflow. Shape 5 only reports a
  # reference the checkout actually tracks, so a case about a read path needs
  # that path to exist in the index.
  local extra
  for extra in "$@"; do
    mkdir -p "$dir/$(dirname "$extra")"
    : > "$dir/$extra"
  done
  git init -q -b main "$dir"
  git -C "$dir" -c user.email=t@t -c user.name=t add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -q -m fixture
}

mk "$sandbox/s1" 'name: s1
on: [push]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: ./tools/verify.sh || true'
check "a discarded exit code is reported" "w.yml:7:swallowed_exit" \
  "$(findings_for "$sandbox/s1" w.yml)"

mk "$sandbox/s2" 'name: s2
on: [push]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - name: measure
        continue-on-error: true
        run: pytest'
check "continue-on-error is reported" "w.yml:8:continue_on_error" \
  "$(findings_for "$sandbox/s2" w.yml)"

# The fixture bodies below are YAML, not shell: `$(...)` inside them is content
# the hook must see verbatim, never something this script should expand.
# shellcheck disable=SC2016
mk "$sandbox/s3" 'name: s3
on: [push]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      # gate-integrity-ok: grep -c exits 1 on no match; the count is the result
      - run: hits=$(grep -c "^kind:" f || true)'
check "a justified site with a reason is accepted" "" \
  "$(findings_for "$sandbox/s3" w.yml)"
check "a justified site exits 0" 0 "$(exit_of "$sandbox/s3" --scan-root .github/workflows --tree-root .)"

# The fixture bodies below are YAML, not shell: `$(...)` inside them is content
# the hook must see verbatim, never something this script should expand.
# shellcheck disable=SC2016
mk "$sandbox/s4" 'name: s4
on: [push]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      # gate-integrity-ok: ok
      - run: hits=$(grep -c "^kind:" f || true)'
check "a marker with too short a reason is not an exemption" "w.yml:8:swallowed_exit" \
  "$(findings_for "$sandbox/s4" w.yml)"

# --- Regressions found while reviewing the adoption PR ----------------------
# Each was a real defect in the ported checker, reproduced by hand before it was
# fixed. Synthetic rather than extracted, because these are shapes the origin
# repository never happened to contain -- which is exactly why they survived the
# port.

mk "$sandbox/r1" 'name: r1
on:
  push:
    paths: ["src/**"]
  pull_request:
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: ./tools/ci/verify.sh' tools/ci/verify.sh
check "an unfiltered sibling trigger covers every path" "" \
  "$(findings_for "$sandbox/r1" w.yml)"

mk "$sandbox/r2" 'name: r2
on:
  push:
    paths-ignore: ["tools/ci/**"]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: ./tools/ci/verify.sh' tools/ci/verify.sh
check "paths-ignore excluding the file the workflow reads is reported" \
  "w.yml:9:uncovered_path_reference" \
  "$(findings_for "$sandbox/r2" w.yml)"

mk "$sandbox/r3" 'name: r3
on:
  push:
    paths:
      - "src/**"  # gate-integrity-ok: tools/ci/verify.sh must not widen this trigger
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: ./tools/ci/verify.sh' tools/ci/verify.sh
check "a marker beside the paths entry exempts the path it names" "" \
  "$(findings_for "$sandbox/r3" w.yml)"

mk "$sandbox/r4" 'name: r4
on:
  pull_request:
    types: [labeled]
    paths: ["src/**"]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: ./tools/ci/verify.sh' tools/ci/verify.sh
check "a label-driven leg is not automatic coverage" \
  "w.yml:10:uncovered_path_reference" \
  "$(findings_for "$sandbox/r4" w.yml)"

# Shape 3 had no synthetic case at all, which is where the job-key defect hid.
# GitHub ${{ … }} expressions are fixture content the hook must see verbatim,
# never something this script should expand.
# shellcheck disable=SC2016
mk "$sandbox/r5" 'name: r5
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.x.outputs.tag }}
    steps:
      - id: x
        run: echo tag=v1
  publish:  # fan-in
    needs: [build]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - run: echo ${{ needs.build.outputs.tag }}'
check "an overridden gate reading outputs without result is reported at its job key" \
  "w.yml:11:unguarded_needs_output" \
  "$(findings_for "$sandbox/r5" w.yml)"

# GitHub ${{ … }} expressions are fixture content the hook must see verbatim,
# never something this script should expand.
# shellcheck disable=SC2016
mk "$sandbox/r6" 'name: r6
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.x.outputs.tag }}
    steps:
      - id: x
        run: echo tag=v1
  # gate-integrity-ok: publish re-checks the tag before it uploads anything
  publish:  # fan-in
    needs: [build]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - run: echo ${{ needs.build.outputs.tag }}'
check "the shape-3 escape hatch is reachable above a commented job key" "" \
  "$(findings_for "$sandbox/r6" w.yml)"

# --- Arguments and failure modes --------------------------------------------
mk "$sandbox/s5" 'name: s5
on: [push]
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: echo fine'
mkdir -p "$sandbox/s5/ci-flows"
cp "$sandbox/s5/.github/workflows/w.yml" "$sandbox/s5/ci-flows/w.yml"
printf '%s\n' '      - run: ./x.sh || true' >> "$sandbox/s5/ci-flows/w.yml"
check "--scan-root redirects the scan" 1 \
  "$(exit_of "$sandbox/s5" --scan-root ci-flows --tree-root .)"
check "the default scan root is unaffected by that file" 0 \
  "$(exit_of "$sandbox/s5" --tree-root .)"

check "a missing scan root is a usage error, not a pass" 2 \
  "$(exit_of "$sandbox/s5" --scan-root does-not-exist --tree-root .)"

# The hook deliberately does NOT short-circuit under CI: it checks CI
# configuration, so a gate that exempts itself from CI would be the shape it
# exists to refuse. This is the one hook in this repository that fails closed.
check "CI=1 does not short-circuit this hook" 1 \
  "$( cd "$sandbox/f1302-red" && CI=1 python3 "$hook" --scan-root .github/workflows --tree-root . >/dev/null 2>&1; echo "$?" )"

# A scan that could not run must not look like a scan that found nothing.
venv="$sandbox/noyaml"
python3 -m venv "$venv" >/dev/null 2>&1
check "a missing YAML parser exits 2, not 0 or 1" 2 \
  "$( cd "$sandbox/s1" && "$venv/bin/python" "$hook" --scan-root .github/workflows --tree-root . >/dev/null 2>&1; echo "$?" )"

echo
echo "Passed: $pass  Failed: $fail"
[ "$fail" -eq 0 ]
