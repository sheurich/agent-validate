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

assert_fail_stderr() {
    local name="$1" expected_pattern="$2" dir="$3"
    shift 3
    local stderr_output
    stderr_output=$("$VALIDATE" "$@" "$dir" 2>&1 >/dev/null) || true
    if echo "$stderr_output" | grep -qE "$expected_pattern"; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (stderr missing pattern: $expected_pattern)" >&2
        echo "  Got: $stderr_output" >&2
        failed=$((failed + 1))
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

# --- Task 1: Tier 1 linter integration ---

# --- Fixture: broken-json ---
assert_fail "broken-json: jsonlint catches invalid JSON" \
    "$FIXTURES/broken-json" --skip "yaml,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Fixture: broken-yaml ---
assert_fail "broken-yaml: yamllint catches invalid YAML" \
    "$FIXTURES/broken-yaml" --skip "json,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Fixture: broken-markdown ---
assert_fail "broken-markdown: markdownlint catches bad markdown" \
    "$FIXTURES/broken-markdown" --skip "json,yaml,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Task 2: Stderr content assertions ---

assert_fail_stderr "broken: stderr reports name mismatch" \
    "Name mismatch.*plugin.json.*gemini-extension.json" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "broken: stderr reports version mismatch" \
    "Version mismatch" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "broken: stderr reports SKILL.md name mismatch" \
    "SKILL.md name mismatch.*wrong-name.*bad-skill" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "broken: stderr reports missing description" \
    "No frontmatter.*description" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

# --- Task 3: Duplicate skills and validate-extra hook ---

assert_fail "duplicate-skills: detects duplicate skill names" \
    "$FIXTURES/duplicate-skills" --skip "$SKIP_EXTERNAL"

assert_fail "extra-hook-fail: failing hook causes overall failure" \
    "$FIXTURES/extra-hook-fail" --skip "$SKIP_EXTERNAL,crosscheck,skills"

assert_pass "extra-hook-pass: passing hook allows success" \
    "$FIXTURES/extra-hook-pass" --skip "$SKIP_EXTERNAL,crosscheck,skills"

# --- Task 4: Config override and Gemini contextFileName ---

assert_pass "config-override: repo-local yamllint config overrides bundled default" \
    "$FIXTURES/config-override" --skip "json,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Fixture: gemini-broken-ctx ---
assert_fail_stderr "gemini-broken-ctx: detects missing context file" \
    "references.*nonexistent.md.*but file not found" \
    "$FIXTURES/gemini-broken-ctx" --skip "$SKIP_EXTERNAL"

# --- Fixture: gemini-valid-ctx ---
assert_pass "gemini-valid-ctx: valid context file passes" \
    "$FIXTURES/gemini-valid-ctx" --skip "$SKIP_EXTERNAL"

# --- Task 5: Edge cases ---

assert_pass "spaces-in-name: handles filenames with spaces" \
    "$FIXTURES/spaces in name" --skip "yaml,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

assert_pass "empty-dir: no files to lint is not an error" \
    "$FIXTURES/empty-dir" --skip "claude,gemini,pi,codex,opencode,crosscheck,skills"

VALIDATE_SKIP="crosscheck,skills" assert_pass "VALIDATE_SKIP env var: merges with --skip" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

echo ""
echo "=== Results: $passed passed, $failed failed ==="

if [[ $failed -gt 0 ]]; then
    exit 1
fi
