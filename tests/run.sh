#!/usr/bin/env bash
# tests/run.sh — Test suite for validate.sh
#
# Usage: ./tests/run.sh [FILTER]
#
# Runs validate.sh against each fixture directory and asserts expected outcomes.
# Optional FILTER pattern matches against test names (substring match).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$REPO_ROOT/validate.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

FILTER="${1:-}"

passed=0
failed=0
skipped=0

assert_pass() {
    local name="$1" dir="$2"
    shift 2
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
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
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
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
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
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

assert_pass_stderr() {
    local name="$1" expected_pattern="$2" dir="$3"
    shift 3
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local stderr_output
    if ! stderr_output=$("$VALIDATE" "$@" "$dir" 2>&1 >/dev/null); then
        echo "FAIL: $name (expected pass, got failure)" >&2
        failed=$((failed + 1))
        return
    fi
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

# --- Fixture: broken-shell (requires shellcheck) ---
if ! command -v shellcheck >/dev/null 2>&1; then
    if [[ -z "$FILTER" || "broken-shell" == *"$FILTER"* ]]; then
        echo "SKIP: broken-shell (shellcheck not installed)"
        skipped=$((skipped + 1))
    fi
else
    assert_fail "broken-shell: shellcheck catches unquoted variable" \
        "$FIXTURES/broken-shell" --skip "json,yaml,markdown,python,claude,gemini,pi,codex,opencode,crosscheck,skills"
fi

# --- Fixture: broken-python ---
assert_fail "broken-python: ruff catches syntax error" \
    "$FIXTURES/broken-python" --skip "json,yaml,markdown,shell,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Task 2: Stderr content assertions ---

assert_fail_stderr "broken: stderr reports name mismatch" \
    "Name mismatch.*plugin.json.*gemini-extension.json" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "broken: stderr reports root plugin.json allowlist violation" \
    "plugin.json has unrecognized fields.*bogus_field" \
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

# --- Item 1: Pi path resolution ---

assert_fail_stderr "pi-broken-path: detects nonexistent pi paths" \
    "pi path does not resolve" \
    "$FIXTURES/pi-broken-path" --skip "json,yaml,markdown,shell,python,claude,gemini,codex,opencode,crosscheck,skills"

assert_pass "pi-valid-paths: valid pi paths pass" \
    "$FIXTURES/pi-valid-paths" --skip "json,yaml,markdown,shell,python,claude,gemini,codex,opencode,crosscheck,skills"

# --- Item 2: Marketplace enumeration logic ---

assert_pass "marketplace-strict-false: strict:false plugins are skipped" \
    "$FIXTURES/marketplace-strict-false" --skip "$SKIP_EXTERNAL"

assert_pass "marketplace-no-root-pj: marketplace without root plugin.json passes" \
    "$FIXTURES/marketplace-no-root-pj" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "marketplace-bad-fields: per-plugin allowlist catches bogus fields" \
    "unrecognized fields" \
    "$FIXTURES/marketplace-bad-fields" --skip "$SKIP_EXTERNAL"

# --- Item 3: Promoted SKILL.md warning path ---

assert_pass "promoted-skill: name mismatch in skills/ grandparent is warning not error" \
    "$FIXTURES/promoted-skill" --skip "$SKIP_EXTERNAL"

# --- Item 4: markdownlint config override ---

assert_pass "mdlint-config-override: repo-local markdownlint config overrides bundled default" \
    "$FIXTURES/mdlint-config-override" --skip "json,yaml,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Drift fix 1: Component path fields in plugin.json ---

assert_pass "plugin-component-paths: component path fields in plugin.json are accepted" \
    "$FIXTURES/plugin-component-paths" --skip "$SKIP_EXTERNAL"

# --- Drift fix 2: contextFileName array handling ---

assert_pass "gemini-ctx-array: contextFileName as array with valid files passes" \
    "$FIXTURES/gemini-ctx-array" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "gemini-ctx-array-broken: contextFileName array detects missing file" \
    "references.*missing.md.*but file not found" \
    "$FIXTURES/gemini-ctx-array-broken" --skip "$SKIP_EXTERNAL"

# --- Drift fix 3: Marketplace top-level validation ---

assert_fail_stderr "marketplace-no-owner: detects missing owner.name" \
    "missing required owner.name" \
    "$FIXTURES/marketplace-no-owner" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "marketplace-bad-source: detects unresolvable source path" \
    "source path does not resolve" \
    "$FIXTURES/marketplace-bad-source" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "marketplace-no-name: detects missing marketplace name" \
    "missing required name field" \
    "$FIXTURES/marketplace-no-name" --skip "$SKIP_EXTERNAL"

# --- Drift fix: Gemini name format ---

assert_fail_stderr "gemini-bad-name: detects non-lowercase extension name" \
    "must be lowercase alphanumeric with dashes" \
    "$FIXTURES/gemini-bad-name" --skip "$SKIP_EXTERNAL"

# --- Drift fix: Pi keyword warning ---

assert_pass_stderr "pi-no-keyword: warns about missing pi-package keyword" \
    "missing.*pi-package.*keyword" \
    "$FIXTURES/pi-no-keyword" --skip "json,yaml,markdown,shell,python,claude,gemini,codex,opencode,crosscheck"

# --- P0 #1: --help flag ---

test_help_flag() {
    local name="--help exits 0"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if "$VALIDATE" --help >/dev/null 2>&1; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (expected exit 0)" >&2
        failed=$((failed + 1))
    fi
}
test_help_flag

test_version_flag() {
    local name="--version exits 0 with version string"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local output
    if output=$("$VALIDATE" --version 2>&1) && echo "$output" | grep -q "^agent-validate "; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name" >&2
        failed=$((failed + 1))
    fi
}
test_version_flag

# --- P0 #4: --skip double-pass concatenation ---

assert_pass "--skip double-pass: two --skip flags concatenate" \
    "$FIXTURES/broken" \
    --skip "$SKIP_EXTERNAL,crosscheck" --skip "skills"

# --- P0 #6: SKILL.md Agent Skills spec alignment ---

assert_fail_stderr "skill-name-too-long: rejects name >64 chars" \
    "exceeds 64-char limit" \
    "$FIXTURES/skill-name-too-long" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-name-uppercase: rejects uppercase in name" \
    "invalid characters.*lowercase" \
    "$FIXTURES/skill-name-uppercase" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-name-leading-hyphen: rejects leading hyphen" \
    "must not start or end with a hyphen" \
    "$FIXTURES/skill-name-leading-hyphen" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-name-consecutive-hyphens: rejects consecutive hyphens" \
    "must not contain consecutive hyphens" \
    "$FIXTURES/skill-name-consecutive-hyphens" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-name-invalid-chars: rejects underscores" \
    "invalid characters.*lowercase" \
    "$FIXTURES/skill-name-invalid-chars" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-description-empty: rejects empty description value" \
    "No frontmatter.*description.*or empty" \
    "$FIXTURES/skill-description-empty" --skip "$SKIP_EXTERNAL,crosscheck"

assert_fail_stderr "skill-description-too-long: rejects description >1024 chars" \
    "Description exceeds 1024-char limit" \
    "$FIXTURES/skill-description-too-long" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-compat-too-long: rejects compatibility >500 chars" \
    "Compatibility exceeds 500-char limit" \
    "$FIXTURES/skill-compat-too-long" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail_stderr "skill-unknown-field: rejects unknown frontmatter field" \
    "Unexpected frontmatter field.*bogus" \
    "$FIXTURES/skill-unknown-field" --skip "$SKIP_EXTERNAL,crosscheck"

assert_pass_stderr "skill-user-invocable: accepts user-invocable with portability warning" \
    "user-invocable.*not part of the Agent Skills specification" \
    "$FIXTURES/skill-user-invocable" --skip "$SKIP_EXTERNAL,crosscheck"

assert_pass_stderr "skill-argument-hint: accepts argument-hint with portability warning" \
    "argument-hint.*not part of the Agent Skills specification" \
    "$FIXTURES/skill-argument-hint" --skip "$SKIP_EXTERNAL,crosscheck"

assert_pass "skill-name-match-skip: name≠folder passes with skill-name-match skipped" \
    "$FIXTURES/skill-name-match-skip" --skip "$SKIP_EXTERNAL,crosscheck,skill-name-match"

assert_fail "skill-name-match-skip: name≠folder fails without skip" \
    "$FIXTURES/skill-name-match-skip" --skip "$SKIP_EXTERNAL,crosscheck"

assert_pass "skill-discovery-paths: discovers skills in .agents/ .claude/ .opencode/" \
    "$FIXTURES/skill-discovery-paths" --skip "$SKIP_EXTERNAL,crosscheck"

assert_pass "skill-all-fields: all allowed frontmatter fields pass" \
    "$FIXTURES/skill-all-fields" --skip "$SKIP_EXTERNAL,crosscheck"

# --- P0 #3: Malformed JSON in crosscheck ---

assert_fail_stderr "crosscheck-malformed-json: reports invalid JSON instead of crashing" \
    "is not valid JSON" \
    "$FIXTURES/crosscheck-malformed-json" --skip "$SKIP_EXTERNAL"

# --- P1 #8: broken-shell and broken-python (see tier 1 section above) ---

# --- P2 #18: Reject .. in marketplace source paths ---

assert_fail_stderr "marketplace-dotdot-source: rejects .. in source path" \
    "contains '\\.\\.'" \
    "$FIXTURES/marketplace-dotdot-source" --skip "$SKIP_EXTERNAL"

# --- P2 #21: Codex/OpenCode detection output ---

test_codex_detection() {
    local name="codex-detection: detects AGENTS.md for Codex"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local stdout
    stdout=$("$VALIDATE" --skip "json,yaml,markdown,shell,python,claude,gemini,pi,opencode,crosscheck,skills" "$FIXTURES/codex-detection" 2>&1)
    if echo "$stdout" | grep -q "Detecting Codex"; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (stdout missing 'Detecting Codex')" >&2
        echo "  Got: $stdout" >&2
        failed=$((failed + 1))
    fi
}
test_codex_detection

test_opencode_detection() {
    local name="opencode-detection: detects AGENTS.md for OpenCode"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local stdout
    stdout=$("$VALIDATE" --skip "json,yaml,markdown,shell,python,claude,gemini,pi,codex,crosscheck,skills" "$FIXTURES/opencode-detection" 2>&1)
    if echo "$stdout" | grep -q "Detecting OpenCode"; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (stdout missing 'Detecting OpenCode')" >&2
        echo "  Got: $stdout" >&2
        failed=$((failed + 1))
    fi
}
test_opencode_detection

# --- P2 #22: Pi auto-detection (directory presence) ---

assert_pass "pi-auto-detect: detects Pi by skills/ directory presence" \
    "$FIXTURES/pi-auto-detect" --skip "json,yaml,markdown,shell,python,claude,gemini,codex,opencode,crosscheck"

# --- P1 #9: CLI edge cases ---

test_unknown_flag() {
    local name="unknown flag exits nonzero"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if "$VALIDATE" --bogus >/dev/null 2>&1; then
        echo "FAIL: $name (expected nonzero exit)" >&2
        failed=$((failed + 1))
    else
        echo "PASS: $name"
        passed=$((passed + 1))
    fi
}
test_unknown_flag

assert_pass "--skip=value equals form works" \
    "$FIXTURES/broken" \
    "--skip=$SKIP_EXTERNAL,crosscheck,skills"

test_multiple_positional() {
    local name="multiple positional args exits nonzero"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if "$VALIDATE" /tmp /tmp >/dev/null 2>&1; then
        echo "FAIL: $name (expected nonzero exit)" >&2
        failed=$((failed + 1))
    else
        echo "PASS: $name"
        passed=$((passed + 1))
    fi
}
test_multiple_positional

# --- Fix: --skip missing value ---

test_skip_missing_value() {
    local name="--skip without value exits nonzero"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if "$VALIDATE" --skip >/dev/null 2>&1; then
        echo "FAIL: $name (expected nonzero exit)" >&2
        failed=$((failed + 1))
    else
        echo "PASS: $name"
        passed=$((passed + 1))
    fi
}
test_skip_missing_value

test_skip_path_value() {
    local name="--skip with path-like value exits nonzero"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if "$VALIDATE" --skip /some/dir >/dev/null 2>&1; then
        echo "FAIL: $name (expected nonzero exit)" >&2
        failed=$((failed + 1))
    else
        echo "PASS: $name"
        passed=$((passed + 1))
    fi
}
test_skip_path_value

test_skip_existing_dir_value() {
    local name="--skip with existing directory as value exits nonzero"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if "$VALIDATE" --skip "$FIXTURES/empty-dir" >/dev/null 2>&1; then
        echo "FAIL: $name (expected nonzero exit)" >&2
        failed=$((failed + 1))
    else
        echo "PASS: $name"
        passed=$((passed + 1))
    fi
}
test_skip_existing_dir_value

# --- Fix: sub-plugin malformed JSON ---

assert_fail_stderr "marketplace-malformed-subplugin: reports invalid sub-plugin JSON" \
    "is not valid JSON" \
    "$FIXTURES/marketplace-malformed-subplugin" --skip "$SKIP_EXTERNAL"

# --- P3: Gemini extension field allowlist ---

assert_fail_stderr "gemini-unknown-field: rejects unknown gemini-extension.json field" \
    "gemini-extension.json has unrecognized fields.*bogus_field" \
    "$FIXTURES/gemini-unknown-field" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "marketplace-gemini-bad-fields: per-plugin Gemini allowlist catches bogus fields" \
    "gemini-extension.json has unrecognized fields.*bogus_gemini_field" \
    "$FIXTURES/marketplace-gemini-bad-fields" --skip "$SKIP_EXTERNAL"

# --- P4: Cross-check mismatch coverage (ge↔pi, pj↔pi, triple) ---

assert_fail_stderr "crosscheck-ge-pi-mismatch: detects ge↔pi name mismatch" \
    "Name mismatch.*gemini-extension.json.*package.json" \
    "$FIXTURES/crosscheck-ge-pi-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-ge-pi-mismatch: detects ge↔pi version mismatch" \
    "Version mismatch.*gemini-extension.json.*package.json" \
    "$FIXTURES/crosscheck-ge-pi-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-ge-pi-mismatch: detects ge↔pi description mismatch" \
    "Description mismatch.*gemini-extension.json.*package.json" \
    "$FIXTURES/crosscheck-ge-pi-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-pj-pi-mismatch: detects pj↔pi name mismatch" \
    "Name mismatch.*plugin.json.*package.json" \
    "$FIXTURES/crosscheck-pj-pi-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-pj-pi-mismatch: detects pj↔pi version mismatch" \
    "Version mismatch.*plugin.json.*package.json" \
    "$FIXTURES/crosscheck-pj-pi-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-pj-pi-mismatch: detects pj↔pi description mismatch" \
    "Description mismatch.*plugin.json.*package.json" \
    "$FIXTURES/crosscheck-pj-pi-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-triple-mismatch: detects all three-way name mismatches" \
    "Name mismatch" \
    "$FIXTURES/crosscheck-triple-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-triple-mismatch: detects all three-way version mismatches" \
    "Version mismatch" \
    "$FIXTURES/crosscheck-triple-mismatch" --skip "$SKIP_EXTERNAL"

assert_fail_stderr "crosscheck-triple-mismatch: detects all three-way description mismatches" \
    "Description mismatch" \
    "$FIXTURES/crosscheck-triple-mismatch" --skip "$SKIP_EXTERNAL"

# --- P5: Codex/OpenCode markdown lint ---

assert_fail "codex-broken-markdown: codex detects markdown lint errors in AGENTS.md" \
    "$FIXTURES/codex-broken-markdown" --skip "json,yaml,markdown,shell,python,claude,gemini,pi,opencode,crosscheck,skills"

# --- P1 #10: dependency-missing paths ---

test_missing_jq() {
    local name="missing jq exits 2"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local exit_code=0
    # Use a restricted PATH unlikely to contain jq
    PATH="/usr/bin:/bin" "$VALIDATE" "$FIXTURES/empty-dir" >/dev/null 2>&1 || exit_code=$?
    if ! PATH="/usr/bin:/bin" command -v jq >/dev/null 2>&1; then
        if [[ $exit_code -eq 2 ]]; then
            echo "PASS: $name"
            passed=$((passed + 1))
        else
            echo "FAIL: $name (expected exit 2, got $exit_code)" >&2
            failed=$((failed + 1))
        fi
    else
        echo "SKIP: $name (jq found on restricted PATH)"
        passed=$((passed + 1))
    fi
}
test_missing_jq

# --- Vendor directory exclusion ---

test_vendor_exclusion() {
    local name="vendor-exclusion: vendor/ contents are excluded from all linters"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    # Create a valid top-level file so linters have something to scan
    echo '{"valid": true}' > "$tmpdir/good.json"

    # Create vendor/ with intentionally broken files
    mkdir -p "$tmpdir/vendor"
    echo '{"trailing-comma": true,}' > "$tmpdir/vendor/bad.json"
    printf 'key: value\n  indented_wrong: true\n' > "$tmpdir/vendor/bad.yml"
    # Literal $UNQUOTED_VAR is intentional — this is a shellcheck test fixture
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\necho $UNQUOTED_VAR\n' > "$tmpdir/vendor/bad.sh"
    printf 'import os\nx = [1,2,3\n' > "$tmpdir/vendor/bad.py"

    if "$VALIDATE" --skip "markdown,claude,gemini,pi,codex,opencode,crosscheck,skills" "$tmpdir" >/dev/null 2>&1; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (expected pass, vendor/ should be excluded)" >&2
        failed=$((failed + 1))
    fi
}
test_vendor_exclusion

# --- Tier 3: --check-deploy flag ---

test_check_deploy_flag() {
    local name="--check-deploy flag is accepted"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    # --check-deploy on empty-dir should pass (no platforms detected)
    if "$VALIDATE" --check-deploy "$FIXTURES/empty-dir" \
        --skip "$SKIP_EXTERNAL" >/dev/null 2>&1; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (expected exit 0)" >&2
        failed=$((failed + 1))
    fi
}
test_check_deploy_flag

test_deploy_claude_check() {
    local name="deploy-claude: parses claude plugin list JSON correctly"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    # Create temp dir with a canned JSON file and a stub claude script
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    # Stub claude that returns canned JSON
    cat > "$tmpdir/claude" << 'STUBEOF'
#!/usr/bin/env bash
if [[ "$*" == *"marketplace list"*"--json"* ]]; then
    echo '[{"name":"test-marketplace"}]'
elif [[ "$*" == *"plugin list"*"--json"* ]]; then
    echo '[{"id":"test-plugin@test-marketplace","enabled":true}]'
fi
STUBEOF
    chmod +x "$tmpdir/claude"

    # Fixture: standalone plugin with marketplace
    mkdir -p "$tmpdir/fix/.claude-plugin"
    cat > "$tmpdir/fix/.claude-plugin/plugin.json" << 'EOF'
{"name":"test-plugin","version":"1.0.0"}
EOF
    cat > "$tmpdir/fix/.claude-plugin/marketplace.json" << 'EOF'
{"name":"test-marketplace","owner":{"name":"o"},"plugins":[
  {"name":"test-plugin","source":"plugins/tp","version":"1.0.0"}
]}
EOF
    mkdir -p "$tmpdir/fix/plugins/tp/.claude-plugin"
    echo '{"name":"test-plugin","version":"1.0.0"}' \
        > "$tmpdir/fix/plugins/tp/.claude-plugin/plugin.json"

    local output
    if output=$(PATH="$tmpdir:$PATH" "$VALIDATE" --check-deploy \
        --skip "$SKIP_EXTERNAL" "$tmpdir/fix" 2>&1); then
        if echo "$output" | grep -q "test-plugin.*installed"; then
            echo "PASS: $name"
            passed=$((passed + 1))
        else
            echo "FAIL: $name (missing expected output)" >&2
            echo "  Got: $output" >&2
            failed=$((failed + 1))
        fi
    else
        echo "FAIL: $name (expected exit 0)" >&2
        echo "  Got: $output" >&2
        failed=$((failed + 1))
    fi
}
test_deploy_claude_check

test_deploy_gemini_check() {
    local name="deploy-gemini: parses gemini extensions list JSON correctly"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    # Stub gemini
    cat > "$tmpdir/gemini" << 'STUBEOF'
#!/usr/bin/env bash
echo '[{"name":"test-ext","version":"1.0.0","isActive":true}]'
STUBEOF
    chmod +x "$tmpdir/gemini"

    # Fixture
    cat > "$tmpdir/gemini-extension.json" << 'EOF'
{"name":"test-ext","version":"1.0.0"}
EOF

    local output
    if output=$(PATH="$tmpdir:$PATH" "$VALIDATE" --check-deploy \
        --skip "$SKIP_EXTERNAL" "$tmpdir" 2>&1); then
        if echo "$output" | grep -q "test-ext.*enabled"; then
            echo "PASS: $name"
            passed=$((passed + 1))
        else
            echo "FAIL: $name (missing expected output)" >&2
            echo "  Got: $output" >&2
            failed=$((failed + 1))
        fi
    else
        echo "FAIL: $name (expected exit 0)" >&2
        echo "  Got: $output" >&2
        failed=$((failed + 1))
    fi
}
test_deploy_gemini_check

test_deploy_skills_hub() {
    local name="deploy-skills-hub: checks skill directories exist"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    # Create fake HOME with skills hub
    mkdir -p "$tmpdir/home/.agents/skills/my-skill"
    mkdir -p "$tmpdir/fix/skills/my-skill"
    cat > "$tmpdir/fix/skills/my-skill/SKILL.md" << 'EOF'
---
name: my-skill
description: test skill
---
# My Skill
EOF

    local output
    if output=$(HOME="$tmpdir/home" "$VALIDATE" --check-deploy \
        --skip "$SKIP_EXTERNAL" "$tmpdir/fix" 2>&1); then
        if echo "$output" | grep -q "my-skill.*found"; then
            echo "PASS: $name"
            passed=$((passed + 1))
        else
            echo "FAIL: $name (missing expected output)" >&2
            echo "  Got: $output" >&2
            failed=$((failed + 1))
        fi
    else
        echo "FAIL: $name (expected exit 0)" >&2
        echo "  Got: $output" >&2
        failed=$((failed + 1))
    fi
}
test_deploy_skills_hub

test_deploy_skills_hub_missing() {
    local name="deploy-skills-hub-missing: detects missing skill directory"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN

    # Create fake HOME WITHOUT skills hub entry
    mkdir -p "$tmpdir/home/.agents/skills"
    mkdir -p "$tmpdir/fix/skills/missing-skill"
    cat > "$tmpdir/fix/skills/missing-skill/SKILL.md" << 'EOF'
---
name: missing-skill
description: test skill
---
# Missing Skill
EOF

    local stderr_output
    stderr_output=$(HOME="$tmpdir/home" "$VALIDATE" --check-deploy \
        --skip "$SKIP_EXTERNAL" "$tmpdir/fix" 2>&1 >/dev/null) || true
    if echo "$stderr_output" | grep -q "missing-skill.*not found"; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name (missing expected error)" >&2
        echo "  Got: $stderr_output" >&2
        failed=$((failed + 1))
    fi
}
test_deploy_skills_hub_missing

# --- Meta-tests: consistency and traceability ---

# Test 1: Ref-comment line accuracy
# Every # Ref: comment in validate.sh must cite a file that exists in
# references/ and line numbers that fall within the file's line count.
test_ref_comment_accuracy() {
    local name="ref-comments: cited files exist and line numbers are in range"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local refs_dir="$REPO_ROOT/skills/spec-conformance/references"
    local errs=()
    while IFS= read -r line; do
        # Extract file and line spec from "# Ref: <file> L<spec>"
        local ref_file ref_lines
        ref_file=$(echo "$line" | sed -E 's/.*# Ref: ([^ ]+) L.*/\1/')
        ref_lines=$(echo "$line" | sed -E 's/.*# Ref: [^ ]+ L([0-9,L-]+).*/\1/')

        if [[ ! -f "$refs_dir/$ref_file" ]]; then
            errs+=("missing file: $ref_file")
            continue
        fi

        local total
        total=$(wc -l < "$refs_dir/$ref_file" | tr -d ' ')

        # Parse line numbers from specs like "49", "49-54", "49,L59",
        # "L296-L340", "L156,L167"
        local nums
        nums=$(echo "$ref_lines" | tr ',L' '\n ' | sed 's/-/\n/g' | tr -s ' \n' '\n' | grep -E '^[0-9]+$')
        while IFS= read -r num; do
            [[ -z "$num" ]] && continue
            if (( num > total )); then
                errs+=("$ref_file L$num out of range (file has $total lines)")
            fi
        done <<< "$nums"
    done < <(grep '# Ref:' "$VALIDATE" | grep -E 'L[0-9]')

    if [[ ${#errs[@]} -eq 0 ]]; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name" >&2
        for e in "${errs[@]}"; do
            echo "  $e" >&2
        done
        failed=$((failed + 1))
    fi
}
test_ref_comment_accuracy

# Test 2: Vendored file inventory consistency
# Every file in references/ must be cited in spec-freshness.yml and SKILL.md.
# Every file cited in spec-freshness.yml must exist in references/.
test_vendored_inventory() {
    local name="vendored-inventory: references/, spec-freshness.yml, and SKILL.md agree"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local refs_dir="$REPO_ROOT/skills/spec-conformance/references"
    local freshness="$REPO_ROOT/.github/workflows/spec-freshness.yml"
    local skillmd="$REPO_ROOT/skills/spec-conformance/SKILL.md"
    local errs=()

    # Files on disk
    local disk_files
    disk_files=$(find "$refs_dir" -maxdepth 1 -type f -exec basename {} \; | sort)

    # Files referenced in spec-freshness.yml (REFS_DIR}/filename patterns)
    local freshness_files
    freshness_files=$(grep -oE 'REFS_DIR\}/[^"]+' "$freshness" \
        | sed 's|REFS_DIR}/||' | sort -u)

    # Files referenced in SKILL.md (references/filename patterns)
    local skillmd_files
    skillmd_files=$(grep -oE 'references/[^ )`]+' "$skillmd" \
        | sed 's|references/||' | sort -u)

    # Check: every disk file in freshness
    while IFS= read -r f; do
        if ! echo "$freshness_files" | grep -qF "$f"; then
            errs+=("$f on disk but not in spec-freshness.yml")
        fi
    done <<< "$disk_files"

    # Check: every disk file in SKILL.md
    while IFS= read -r f; do
        if ! echo "$skillmd_files" | grep -qF "$f"; then
            errs+=("$f on disk but not in SKILL.md")
        fi
    done <<< "$disk_files"

    # Check: every freshness file on disk
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ ! -f "$refs_dir/$f" ]]; then
            errs+=("$f in spec-freshness.yml but not on disk")
        fi
    done <<< "$freshness_files"

    if [[ ${#errs[@]} -eq 0 ]]; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name" >&2
        for e in "${errs[@]}"; do
            echo "  $e" >&2
        done
        failed=$((failed + 1))
    fi
}
test_vendored_inventory

# Test 3: CLI-regression fixture paths exist
# Every tests/fixtures/ path in cli-regression.yml must exist on disk.
test_cli_regression_fixtures() {
    local name="cli-regression-fixtures: all referenced fixture paths exist"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    local workflow="$REPO_ROOT/.github/workflows/cli-regression.yml"
    if [[ ! -f "$workflow" ]]; then
        echo "SKIP: $name (cli-regression.yml not found)"
        skipped=$((skipped + 1))
        return
    fi
    local errs=()
    while IFS= read -r fixture_path; do
        [[ -z "$fixture_path" ]] && continue
        if [[ ! -e "$REPO_ROOT/$fixture_path" ]]; then
            errs+=("$fixture_path does not exist")
        fi
    done < <(grep -oE 'tests/fixtures/[^ "]+' "$workflow" | sort -u)

    if [[ ${#errs[@]} -eq 0 ]]; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name" >&2
        for e in "${errs[@]}"; do
            echo "  $e" >&2
        done
        failed=$((failed + 1))
    fi
}
test_cli_regression_fixtures

# Test 4: Workflow structural validation (actionlint)
test_actionlint() {
    local name="actionlint: workflow files are structurally valid"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    if ! command -v actionlint >/dev/null 2>&1; then
        echo "SKIP: $name (actionlint not installed)"
        skipped=$((skipped + 1))
        return
    fi
    local output
    if output=$(actionlint "$REPO_ROOT/.github/workflows/"*.yml 2>&1); then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name" >&2
        echo "$output" >&2
        failed=$((failed + 1))
    fi
}
test_actionlint

# Test 5: Skip-value documentation parity
# Values listed in usage() must match values passed to should_skip in the script.
test_skip_parity() {
    local name="skip-parity: usage() documents all should_skip values and vice versa"
    if [[ -n "$FILTER" ]] && [[ "$name" != *"$FILTER"* ]]; then
        skipped=$((skipped + 1))
        return
    fi
    # Extract skip values from usage() block (indented words between
    # "Skip values:" and the next blank line)
    local usage_vals
    usage_vals=$(sed -n '/^Skip values:/,/^$/p' "$VALIDATE" \
        | grep -E '^\s+\S+' | awk '{print $1}' | sort)

    # Extract skip values from should_skip calls
    local code_vals
    code_vals=$(grep -oE 'should_skip "[^"]+"' "$VALIDATE" \
        | sed 's/should_skip "//;s/"//' | sort -u)

    local errs=()
    # Every usage value must appear in code
    while IFS= read -r v; do
        [[ -z "$v" ]] && continue
        if ! echo "$code_vals" | grep -qxF "$v"; then
            errs+=("'$v' in usage() but no should_skip call")
        fi
    done <<< "$usage_vals"

    # Every code value must appear in usage
    while IFS= read -r v; do
        [[ -z "$v" ]] && continue
        if ! echo "$usage_vals" | grep -qxF "$v"; then
            errs+=("'$v' in should_skip call but not in usage()")
        fi
    done <<< "$code_vals"

    if [[ ${#errs[@]} -eq 0 ]]; then
        echo "PASS: $name"
        passed=$((passed + 1))
    else
        echo "FAIL: $name" >&2
        for e in "${errs[@]}"; do
            echo "  $e" >&2
        done
        failed=$((failed + 1))
    fi
}
test_skip_parity

echo ""
if [[ -n "$FILTER" ]]; then
    echo "=== Results: $passed passed, $failed failed, $skipped skipped (filter: \"$FILTER\") ==="
elif [[ $skipped -gt 0 ]]; then
    echo "=== Results: $passed passed, $failed failed, $skipped skipped ==="
else
    echo "=== Results: $passed passed, $failed failed ==="
fi

if [[ $failed -gt 0 ]]; then
    exit 1
fi
