#!/usr/bin/env bash
# tests/run.sh — Test suite for validate.sh
#
# Runs validate.sh against each fixture directory and asserts expected outcomes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$REPO_ROOT/validate.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

passed=0
failed=0

assert_pass() {
    local name="$1" dir="$2"
    shift 2
    if "$VALIDATE" "$@" "$dir" >/dev/null 2>&1; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (expected pass, got exit $?)" >&2
        failed=$((failed + 1))
    fi
}

assert_fail() {
    local name="$1" dir="$2"
    shift 2
    if "$VALIDATE" "$@" "$dir" >/dev/null 2>&1; then
        echo "FAIL: $name (expected failure, got exit 0)" >&2
        failed=$((failed + 1))
    else
        echo "PASS: $name (correctly failed)"
        passed=$((passed + 1))
    fi
}

# Skip checks that require npm/claude/gemini CLI tools in CI-less environments.
# The structural checks (crosscheck, skills, allowlist) are the ones we test.
SKIP_EXTERNAL="json,yaml,markdown,shell,python,claude,gemini,pi,codex,opencode"

echo "=== Running agent-validate tests ==="
echo ""

# --- Fixture: standalone-plugin ---
assert_pass "standalone-plugin: crosscheck passes" \
    "$FIXTURES/standalone-plugin" --skip "$SKIP_EXTERNAL"

# --- Fixture: marketplace ---
assert_pass "marketplace: crosscheck passes" \
    "$FIXTURES/marketplace" --skip "$SKIP_EXTERNAL"

# --- Fixture: skills-only ---
assert_pass "skills-only: skill frontmatter passes" \
    "$FIXTURES/skills-only" --skip "$SKIP_EXTERNAL"

# --- Fixture: pi-package ---
assert_pass "pi-package: pi detection passes" \
    "$FIXTURES/pi-package" --skip "$SKIP_EXTERNAL"

# --- Fixture: broken ---
assert_fail "broken: crosscheck detects mismatches" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

# --- Skip flag ---
assert_pass "broken: passes when all checks skipped" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL,crosscheck,skills"

echo ""
echo "=== Results: $passed passed, $failed failed ==="

if [[ $failed -gt 0 ]]; then
    exit 1
fi
