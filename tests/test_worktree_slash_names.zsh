#!/usr/bin/env zsh
# Integration test for worktree name extraction with slash-containing branches.
# Exercises _wt_list_names, _wt_tui_data, and the grep -xF branch extraction
# pattern used in _wt_remove / _wt_remove_glob.
#
# Usage: zsh tests/test_worktree_slash_names.zsh
set -e
PASS=0; FAIL=0

# Resolve PLUGIN_DIR from the script's location before any cd.
PLUGIN_DIR="${0:A:h:h}"

assert_eq() {
  if [[ "$1" == "$2" ]]; then ((PASS++)) || true; echo "  PASS: $3"
  else ((FAIL++)) || true; echo "  FAIL: $3"; echo "    expected: $2"; echo "    got:      $1"; fi
}
assert_not_contains() {
  if [[ "$1" != *"$2"* ]]; then ((PASS++)) || true; echo "  PASS: $3"
  else ((FAIL++)) || true; echo "  FAIL: $3 — found '$2' in output"; fi
}
assert_contains() {
  if [[ "$1" == *"$2"* ]]; then ((PASS++)) || true; echo "  PASS: $3"
  else ((FAIL++)) || true; echo "  FAIL: $3 — did not find '$2' in output"; fi
}

# --- Setup: bare repo structure with slash-named worktrees ---
# Use resolved path to avoid macOS /var → /private/var symlink mismatch
TEST_DIR=$(cd "$(mktemp -d)" && pwd -P)
trap "rm -rf $TEST_DIR" EXIT

echo "Setting up test fixtures in $TEST_DIR..."

# Create a source repo to clone from
mkdir -p "$TEST_DIR/source" && cd "$TEST_DIR/source"
git init -b main --quiet
git commit --allow-empty -m "init" --quiet
git branch feature/login
git branch feature/api/v2
git branch bugfix

# Create bare-repo worktree structure (mirrors `worktree dir`)
mkdir -p "$TEST_DIR/project" && cd "$TEST_DIR/project"
git clone --bare "$TEST_DIR/source" .bare --quiet
echo "gitdir: ./.bare" > .git
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin --quiet
git worktree add main main --quiet 2>/dev/null
git worktree add bugfix bugfix --quiet 2>/dev/null
git worktree add feature/login feature/login --quiet 2>/dev/null
git worktree add feature/api/v2 feature/api/v2 --quiet 2>/dev/null

# Source plugin functions
for f in "$PLUGIN_DIR"/functions/*; do source "$f"; done

cd "$TEST_DIR/project/main"  # must be inside a worktree

echo ""
echo "=== Test Suite: Worktree Slash-Name Handling ==="
echo ""

# --- Test 1: _wt_list_names returns full slash-containing names ---
echo "Test 1: _wt_list_names preserves slash names"
result=$(_wt_list_names)
assert_contains "$result" "feature/login" "feature/login in output"
assert_contains "$result" "feature/api/v2" "feature/api/v2 in output"
assert_contains "$result" "bugfix" "bugfix in output"

# --- Test 2: _wt_list_names does NOT return .bare ---
echo ""
echo "Test 2: _wt_list_names excludes .bare"
assert_not_contains "$result" ".bare" ".bare excluded"

# --- Test 3: --exclude-main ---
echo ""
echo "Test 3: --exclude-main flag"
result_no_main=$(_wt_list_names --exclude-main)
assert_not_contains "$result_no_main" "main" "main excluded with flag"
assert_contains "$result_no_main" "feature/login" "feature/login still present"

# --- Test 4: _wt_tui_data JSON has full names, no bare ---
echo ""
echo "Test 4: _wt_tui_data JSON output"
json=$(_wt_tui_data)
assert_contains "$json" '"name":"feature/login"' "TUI data: feature/login name"
assert_contains "$json" '"name":"feature/api/v2"' "TUI data: feature/api/v2 name"
assert_not_contains "$json" '"is_bare":true' "TUI data: no bare entries emitted"

# --- Test 5: branch extraction with grep -xF works for slash names ---
echo ""
echo "Test 5: branch extraction (grep -xF) for slash-named worktrees"
worktrees_dir=$(_get_worktree_root)

branch_name=$(git worktree list --porcelain | \
  grep -xF "worktree $worktrees_dir/feature/login" -A 2 | \
  awk '/^branch/ { sub(/^refs\/heads\//, "", $2); print $2; exit }')
assert_eq "$branch_name" "feature/login" "branch extraction: feature/login"

branch_name2=$(git worktree list --porcelain | \
  grep -xF "worktree $worktrees_dir/feature/api/v2" -A 2 | \
  awk '/^branch/ { sub(/^refs\/heads\//, "", $2); print $2; exit }')
assert_eq "$branch_name2" "feature/api/v2" "branch extraction: feature/api/v2"

# --- Test 6: old basename pipeline truncates slash names (regression guard) ---
echo ""
echo "Test 6: old basename pipeline truncates slash names"
old_names=$(git worktree list --porcelain | \
  grep '^worktree ' | \
  awk '{print $2}' | \
  xargs -n1 basename)
assert_contains "$old_names" "login" "old basename pipeline returns truncated 'login'"
assert_not_contains "$old_names" "feature/login" "old basename pipeline loses 'feature/login'"

# --- Test 7: old regex grep misses slash names ---
echo ""
echo "Test 7: old regex grep pattern fails for slash names"
# The old pattern "worktree.*/${worktree_name}$" uses regex which can match wrong entries
old_result=$(git worktree list --porcelain | \
  grep -c "worktree.*/feature/login$" 2>/dev/null || true)
# This may or may not match depending on the path — the issue is it's not exact.
# The fixed grep -xF always matches exactly.
fixed_result=$(git worktree list --porcelain | \
  grep -cxF "worktree $worktrees_dir/feature/login" 2>/dev/null || true)
assert_eq "$fixed_result" "1" "grep -xF finds exactly one match for feature/login"

# --- Summary ---
echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
