# Test Coverage Expansion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the test coverage gaps identified in the self-testing strategy review — tier 1 linter integration, stderr content assertions, edge cases, config override verification, validate-extra hook, duplicate skill detection, and Gemini contextFileName resolution.

**Architecture:** Six independent task groups, each adding fixtures and test assertions to the existing `tests/` structure. Tasks 1–5 modify only fixtures and `tests/run.sh`. Task 6 modifies `validate.sh` to fix a bug surfaced during analysis. All tasks share the same files (`tests/run.sh`, `validate.sh`) but touch non-overlapping sections.

**Tech Stack:** Bash, jq, shellcheck, jsonlint-mod, yamllint, markdownlint-cli

---

## Tasks

### Task 1: Tier 1 linter integration tests

Add fixtures with intentionally broken JSON, YAML, and Markdown files. Enable only the relevant linter for each test (skip everything else). These tools are available via npx/uvx and work without external API credentials.

**Files:**
- Create: `tests/fixtures/broken-json/bad.json`
- Create: `tests/fixtures/broken-json/README.md`
- Create: `tests/fixtures/broken-yaml/bad.yml`
- Create: `tests/fixtures/broken-yaml/README.md`
- Create: `tests/fixtures/broken-markdown/bad.md`
- Create: `tests/fixtures/broken-markdown/.markdownlint.json`
- Modify: `tests/run.sh` (append new assertions)

**Step 1: Create broken-json fixture**

`tests/fixtures/broken-json/bad.json`:
```json
{"trailing-comma": true,}
```

`tests/fixtures/broken-json/README.md`:
```markdown
# Broken JSON

Fixture with invalid JSON to test jsonlint-mod detection.
```

**Step 2: Create broken-yaml fixture**

`tests/fixtures/broken-yaml/bad.yml`:
```yaml
key: value
  indented_wrong: true
```

`tests/fixtures/broken-yaml/README.md`:
```markdown
# Broken YAML

Fixture with invalid YAML to test yamllint detection.
```

**Step 3: Create broken-markdown fixture**

`tests/fixtures/broken-markdown/bad.md` — a file that violates MD001 (heading increment) which is enabled by default:
```markdown
# Heading 1

### Heading 3 skipping 2
```

`tests/fixtures/broken-markdown/.markdownlint.json` — enable only MD001 to guarantee the failure is from our bad file and nothing else:
```json
{
  "default": true,
  "MD013": false
}
```

**Step 4: Add assertions to tests/run.sh**

Append before the results summary:

```bash
# --- Fixture: broken-json ---
assert_fail "broken-json: jsonlint catches invalid JSON" \
    "$FIXTURES/broken-json" --skip "yaml,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Fixture: broken-yaml ---
assert_fail "broken-yaml: yamllint catches invalid YAML" \
    "$FIXTURES/broken-yaml" --skip "json,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Fixture: broken-markdown ---
assert_fail "broken-markdown: markdownlint catches bad markdown" \
    "$FIXTURES/broken-markdown" --skip "json,yaml,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"
```

**Step 5: Run tests, verify 9 pass**

Run: `./tests/run.sh`
Expected: 9 passed, 0 failed

**Step 6: Lint and commit**

```bash
shellcheck tests/run.sh
find tests/fixtures/broken-json tests/fixtures/broken-yaml -name "*.md" -exec npx --yes markdownlint-cli@0.47.0 {} + --config defaults/.markdownlint.json
git add tests/
git commit -m "test: add tier 1 linter integration tests

Add broken-json, broken-yaml, broken-markdown fixtures that exercise
jsonlint-mod, yamllint, and markdownlint detection of invalid files."
```

---

### Task 2: Stderr content assertions

Replace exit-code-only checking with a helper that also inspects stderr for expected error messages. Retrofit existing broken-fixture test, add new targeted assertions.

**Files:**
- Modify: `tests/run.sh` (add `assert_fail_stderr` helper, update broken test, add new assertions)

**Step 1: Add assert_fail_stderr helper**

Insert after the existing `assert_fail` function in `tests/run.sh`:

```bash
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
```

**Step 2: Add stderr assertions for the broken fixture**

Append new test cases:

```bash
# --- Fixture: broken — stderr content ---
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
```

**Step 3: Run tests, verify all pass**

Run: `./tests/run.sh`
Expected: all passed (count depends on whether Task 1 is already merged)

**Step 4: Lint and commit**

```bash
shellcheck tests/run.sh
git add tests/run.sh
git commit -m "test: add stderr content assertions

Add assert_fail_stderr helper. Verify broken fixture produces the
expected error messages, not just a nonzero exit code."
```

---

### Task 3: Duplicate skill names and validate-extra hook

Add a fixture with duplicate skill names. Add a fixture with a `scripts/validate-extra.sh` hook that fails. Add a fixture with a hook that passes.

**Files:**
- Create: `tests/fixtures/duplicate-skills/skills/alpha/SKILL.md`
- Create: `tests/fixtures/duplicate-skills/skills/beta/SKILL.md` (same name as alpha)
- Create: `tests/fixtures/duplicate-skills/README.md`
- Create: `tests/fixtures/extra-hook-fail/scripts/validate-extra.sh`
- Create: `tests/fixtures/extra-hook-fail/README.md`
- Create: `tests/fixtures/extra-hook-pass/scripts/validate-extra.sh`
- Create: `tests/fixtures/extra-hook-pass/README.md`
- Modify: `tests/run.sh` (append assertions)

**Step 1: Create duplicate-skills fixture**

`tests/fixtures/duplicate-skills/skills/alpha/SKILL.md`:
```markdown
---
name: alpha
description: First alpha
---

# Alpha
```

`tests/fixtures/duplicate-skills/skills/beta/SKILL.md`:
```markdown
---
name: alpha
description: Duplicate of alpha (wrong)
---

# Beta with wrong name
```

`tests/fixtures/duplicate-skills/README.md`:
```markdown
# Duplicate Skills

Fixture with two skills sharing the same frontmatter name.
```

**Step 2: Create extra-hook fixtures**

`tests/fixtures/extra-hook-fail/scripts/validate-extra.sh`:
```bash
#!/usr/bin/env bash
echo "Error: extra hook failed" >&2
exit 1
```

`tests/fixtures/extra-hook-fail/README.md`:
```markdown
# Extra Hook Fail

Fixture with a validate-extra.sh that exits nonzero.
```

`tests/fixtures/extra-hook-pass/scripts/validate-extra.sh`:
```bash
#!/usr/bin/env bash
echo "Extra hook ran successfully"
exit 0
```

`tests/fixtures/extra-hook-pass/README.md`:
```markdown
# Extra Hook Pass

Fixture with a validate-extra.sh that exits zero.
```

Make both hooks executable: `chmod +x tests/fixtures/extra-hook-*/scripts/validate-extra.sh`

**Step 3: Add assertions to tests/run.sh**

```bash
# --- Fixture: duplicate-skills ---
assert_fail "duplicate-skills: detects duplicate skill names" \
    "$FIXTURES/duplicate-skills" --skip "$SKIP_EXTERNAL"

# --- Fixture: extra-hook-fail ---
assert_fail "extra-hook-fail: failing hook causes overall failure" \
    "$FIXTURES/extra-hook-fail" --skip "$SKIP_EXTERNAL,crosscheck,skills"

# --- Fixture: extra-hook-pass ---
assert_pass "extra-hook-pass: passing hook allows success" \
    "$FIXTURES/extra-hook-pass" --skip "$SKIP_EXTERNAL,crosscheck,skills"
```

**Step 4: Run tests, verify all pass**

Run: `./tests/run.sh`

**Step 5: Lint and commit**

```bash
shellcheck tests/run.sh tests/fixtures/extra-hook-*/scripts/validate-extra.sh
git add tests/
git commit -m "test: add duplicate skill and validate-extra hook fixtures

Duplicate-skills fixture has two SKILL.md files with the same
frontmatter name. Extra-hook fixtures exercise scripts/validate-extra.sh
pass and fail paths."
```

---

### Task 4: Config override and Gemini contextFileName tests

Test that a repo-local `.yamllint.yml` overrides the bundled default. Test Gemini contextFileName resolution (the structural check, not the `gemini extensions validate` CLI call).

**Files:**
- Create: `tests/fixtures/config-override/.yamllint.yml`
- Create: `tests/fixtures/config-override/long-line.yml`
- Create: `tests/fixtures/config-override/README.md`
- Create: `tests/fixtures/gemini-broken-ctx/gemini-extension.json`
- Create: `tests/fixtures/gemini-broken-ctx/.claude-plugin/plugin.json`
- Create: `tests/fixtures/gemini-broken-ctx/README.md`
- Create: `tests/fixtures/gemini-valid-ctx/gemini-extension.json`
- Create: `tests/fixtures/gemini-valid-ctx/context.md`
- Create: `tests/fixtures/gemini-valid-ctx/.claude-plugin/plugin.json`
- Create: `tests/fixtures/gemini-valid-ctx/README.md`
- Modify: `tests/run.sh` (append assertions)

**Step 1: Create config-override fixture**

The bundled `.yamllint.yml` allows lines up to 120 characters. The repo-local config will allow up to 200. The fixture YAML file has a line of ~150 chars. With bundled config it would fail; with the override it passes.

`tests/fixtures/config-override/.yamllint.yml`:
```yaml
---
extends: default

rules:
  line-length:
    max: 200
  truthy:
    check-keys: false
  document-start: disable
```

`tests/fixtures/config-override/long-line.yml`:
```yaml
long_key: "this is a deliberately long value that exceeds the default 120-character limit but stays under the repo-local 200 character limit so validation should pass with the override"
```

`tests/fixtures/config-override/README.md`:
```markdown
# Config Override

Fixture testing that repo-local yamllint config overrides the bundled default.
```

**Step 2: Create Gemini contextFileName fixtures**

`tests/fixtures/gemini-broken-ctx/gemini-extension.json`:
```json
{
  "name": "broken-ctx",
  "description": "Broken context",
  "version": "1.0.0",
  "contextFileName": "nonexistent.md"
}
```

`tests/fixtures/gemini-broken-ctx/.claude-plugin/plugin.json`:
```json
{
  "name": "broken-ctx",
  "description": "Broken context",
  "version": "1.0.0"
}
```

`tests/fixtures/gemini-broken-ctx/README.md`:
```markdown
# Gemini Broken Context

Fixture where gemini-extension.json references a nonexistent context file.
```

`tests/fixtures/gemini-valid-ctx/gemini-extension.json`:
```json
{
  "name": "valid-ctx",
  "description": "Valid context",
  "version": "1.0.0",
  "contextFileName": "context.md"
}
```

`tests/fixtures/gemini-valid-ctx/.claude-plugin/plugin.json`:
```json
{
  "name": "valid-ctx",
  "description": "Valid context",
  "version": "1.0.0"
}
```

`tests/fixtures/gemini-valid-ctx/context.md`:
```markdown
# Gemini Context

This file exists.
```

`tests/fixtures/gemini-valid-ctx/README.md`:
```markdown
# Gemini Valid Context

Fixture where gemini-extension.json references an existing context file.
```

**Step 3: Add assertions to tests/run.sh**

The Gemini contextFileName check is inside the `should_skip "gemini"` block, but the `gemini extensions validate` CLI call is what we want to skip, not the contextFileName file resolution. This is a **bug in validate.sh** — the contextFileName file existence check is gated behind `should_skip "gemini"`, but it's a structural check that doesn't need the Gemini CLI. Task 6 will fix this. For now, these tests serve as the spec.

```bash
# --- Fixture: config-override ---
assert_pass "config-override: repo-local yamllint config overrides bundled default" \
    "$FIXTURES/config-override" --skip "json,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"
```

For the Gemini tests, since the contextFileName check is currently inside the gemini skip guard, we need to NOT skip gemini. But `gemini extensions validate` will fail without the tool. After Task 6 separates the structural check, these will work with gemini skipped. Until then, mark them as pending or skip. Add them commented out with a note:

```bash
# --- Fixture: gemini-broken-ctx ---
# NOTE: Requires Task 6 (extract contextFileName check from gemini skip guard)
# assert_fail_stderr "gemini-broken-ctx: detects missing context file" \
#     "references.*nonexistent.md.*but file not found" \
#     "$FIXTURES/gemini-broken-ctx" --skip "$SKIP_EXTERNAL"

# --- Fixture: gemini-valid-ctx ---
# assert_pass "gemini-valid-ctx: valid context file passes" \
#     "$FIXTURES/gemini-valid-ctx" --skip "$SKIP_EXTERNAL"
```

**Step 4: Run tests, verify config-override passes**

Run: `./tests/run.sh`

**Step 5: Lint and commit**

```bash
shellcheck tests/run.sh
find tests/fixtures/config-override tests/fixtures/gemini-broken-ctx tests/fixtures/gemini-valid-ctx -name "*.json" -print0 | xargs -0 -n1 npx --yes jsonlint-mod@1.7.6 -q
uvx yamllint@1.37.0 -c tests/fixtures/config-override/.yamllint.yml tests/fixtures/config-override/long-line.yml
git add tests/
git commit -m "test: add config override and Gemini contextFileName fixtures

Config-override fixture verifies repo-local .yamllint.yml takes
precedence over bundled default. Gemini fixtures test contextFileName
resolution (assertions commented pending Task 6 refactor)."
```

---

### Task 5: Edge cases — spaces in filenames, empty directories, VALIDATE_SKIP env var

Test `-print0`/`xargs -0` safety with spaces in filenames. Test that empty fixture directories don't cause errors. Test `VALIDATE_SKIP` env var merges with `--skip`.

**Files:**
- Create: `tests/fixtures/spaces in name/valid.json`
- Create: `tests/fixtures/spaces in name/README.md`
- Create: `tests/fixtures/empty-dir/README.md`
- Modify: `tests/run.sh` (append assertions)

**Step 1: Create spaces-in-name fixture**

`tests/fixtures/spaces in name/valid.json`:
```json
{
  "key": "value"
}
```

`tests/fixtures/spaces in name/README.md`:
```markdown
# Spaces In Name

Fixture testing safe filename handling with spaces.
```

**Step 2: Create empty-dir fixture**

`tests/fixtures/empty-dir/README.md`:
```markdown
# Empty Dir

Fixture with no JSON, YAML, shell, or Python files.
```

**Step 3: Add assertions to tests/run.sh**

```bash
# --- Fixture: spaces in name ---
assert_pass "spaces-in-name: handles filenames with spaces" \
    "$FIXTURES/spaces in name" --skip "yaml,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- Fixture: empty-dir ---
assert_pass "empty-dir: no files to lint is not an error" \
    "$FIXTURES/empty-dir" --skip "claude,gemini,pi,codex,opencode,crosscheck,skills"

# --- VALIDATE_SKIP env var ---
VALIDATE_SKIP="crosscheck,skills" assert_pass "VALIDATE_SKIP env var: merges with --skip" \
    "$FIXTURES/broken" --skip "$SKIP_EXTERNAL"
```

**Step 4: Run tests, verify all pass**

Run: `./tests/run.sh`

**Step 5: Lint and commit**

```bash
shellcheck tests/run.sh
git add tests/
git commit -m "test: add edge case tests for spaces, empty dirs, VALIDATE_SKIP

Spaces-in-name fixture exercises -print0/xargs -0 filename safety.
Empty-dir fixture verifies graceful handling of no matching files.
VALIDATE_SKIP assertion verifies env var merges with --skip flag."
```

---

### Task 6: Extract Gemini contextFileName check from gemini skip guard

The contextFileName file-existence check is a structural validation (does the referenced file exist?). It doesn't need `gemini extensions validate`. Currently it's gated behind `should_skip "gemini"`, which means consumers who skip the Gemini CLI tool also lose this file-resolution check. Extract it into the crosscheck section.

**Files:**
- Modify: `validate.sh` (move contextFileName checks into crosscheck block)
- Modify: `tests/run.sh` (uncomment Gemini fixture assertions from Task 4)

**Step 1: In validate.sh, remove contextFileName checks from the gemini block**

Find and remove the two contextFileName sections:
1. The root-level contextFileName check (lines after `gemini extensions validate .`)
2. The marketplace sub-plugin contextFileName check (the `if [[ -f "$marketplace" ]]` block inside the gemini guard)

**Step 2: In validate.sh, add contextFileName checks to the crosscheck block**

Insert before the marketplace cross-checks section, still inside `if ! should_skip "crosscheck"`:

```bash
    # Gemini contextFileName file resolution
    if [[ -f "$gemini_json" ]]; then
        context_file=$(jq -r '.contextFileName // empty' "$gemini_json")
        if [[ -n "$context_file" ]]; then
            if [[ ! -f "$context_file" ]]; then
                echo "Error: gemini-extension.json references '$context_file' but file not found" >&2
                errors=$((errors + 1))
            fi
        else
            if [[ ! -f "GEMINI.md" ]]; then
                echo "Note: No contextFileName and no GEMINI.md (Gemini gets no root context)"
            fi
        fi
    fi

    # Marketplace sub-plugin contextFileName resolution
    if [[ -f "$marketplace" ]]; then
        mp_ctx_count=$(jq -e -r '.plugins | length' "$marketplace" 2>/dev/null) || mp_ctx_count=0
        for ((i = 0; i < mp_ctx_count; i++)); do
            mp_source=$(jq -r ".plugins[$i].source" "$marketplace")
            mp_strict=$(jq -r "if .plugins[$i].strict == false then \"false\" else \"true\" end" "$marketplace")
            [[ "$mp_strict" == "false" ]] && continue

            sub_gemini="$mp_source/gemini-extension.json"
            [[ -f "$sub_gemini" ]] || continue

            mp_name=$(jq -r ".plugins[$i].name" "$marketplace")
            sub_ctx=$(jq -r '.contextFileName // empty' "$sub_gemini")
            if [[ -n "$sub_ctx" ]]; then
                if [[ ! -f "$mp_source/$sub_ctx" ]]; then
                    echo "Error: $mp_name gemini-extension.json references '$sub_ctx' but file not found" >&2
                    errors=$((errors + 1))
                fi
            else
                if [[ ! -f "$mp_source/GEMINI.md" ]]; then
                    echo "Note: $mp_name has no contextFileName and no GEMINI.md (Gemini gets no root context)"
                fi
            fi
        done
    fi
```

**Step 3: Uncomment Gemini fixture assertions in tests/run.sh**

Replace the commented-out Gemini assertions (from Task 4) with active ones:

```bash
# --- Fixture: gemini-broken-ctx ---
assert_fail_stderr "gemini-broken-ctx: detects missing context file" \
    "references.*nonexistent.md.*but file not found" \
    "$FIXTURES/gemini-broken-ctx" --skip "$SKIP_EXTERNAL"

# --- Fixture: gemini-valid-ctx ---
assert_pass "gemini-valid-ctx: valid context file passes" \
    "$FIXTURES/gemini-valid-ctx" --skip "$SKIP_EXTERNAL"
```

**Step 4: Run tests, verify all pass including new Gemini assertions**

Run: `./tests/run.sh`

**Step 5: Verify existing tests still pass**

Run: `./tests/run.sh`
Expected: all passed

**Step 6: Lint and commit**

```bash
shellcheck validate.sh tests/run.sh
git add validate.sh tests/run.sh
git commit -m "refactor: extract contextFileName check from gemini skip guard

The contextFileName file-existence check is structural validation that
doesn't require the Gemini CLI. Move it into the crosscheck block so
consumers who skip gemini still get file-resolution validation."
```

---

### Dependency graph

```
Task 1 (linter fixtures)     — independent
Task 2 (stderr assertions)   — independent
Task 3 (dupes + hook)        — independent
Task 4 (config + gemini ctx) — independent (gemini tests commented)
Task 5 (edge cases)          — independent
Task 6 (validate.sh refactor + uncomment gemini tests) — depends on Task 4 fixtures
```

Tasks 1–5 are independent. Task 6 depends on Task 4's fixture files but modifies different code (`validate.sh` and uncommenting lines in `tests/run.sh`).

### Parallelization plan

**Wave 1 (parallel):** Tasks 1, 2, 3, 4, 5 — all on separate branches
**Wave 2 (sequential):** Task 6 — after Task 4 merges, on its own branch

### Final verification

After all tasks merge to main:
```bash
shellcheck validate.sh tests/run.sh
./tests/run.sh
```

Expected: all tests pass, shellcheck clean.
