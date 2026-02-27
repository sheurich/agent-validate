#!/usr/bin/env bash
# validate.sh — Cross-agent plugin/extension/skill validation
#
# Usage:
#   ./validate.sh [--skip CHECKS] [--verbose] [--quiet] [--version] [-h|--help] [TARGET_DIR]
#
# Environment variables:
#   VALIDATE_SKIP          Comma-separated checks to skip
#   JSONLINT_VERSION       jsonlint-mod version (default: 1.7.6)
#   YAMLLINT_VERSION       yamllint version (default: 1.37.0)
#   MARKDOWNLINT_VERSION   markdownlint-cli version (default: 0.47.0)
#   RUFF_VERSION           ruff version (default: 0.14.14)
#   CLAUDE_CODE_VERSION    @anthropic-ai/claude-code version (default: 2.1.22)
#   GEMINI_CLI_VERSION     @google/gemini-cli version (default: 0.26.0)
#   TYPESCRIPT_VERSION     typescript version (default: 5.8.3)

set -euo pipefail

VALIDATE_VERSION="1.0.0"

# --- Usage ---
usage() {
    cat <<'EOF'
Usage: validate.sh [OPTIONS] [TARGET_DIR]

Cross-agent plugin/extension/skill validation.

Options:
  --skip CHECKS   Comma-separated checks to skip (repeatable)
  --verbose       Show detailed output
  --quiet         Show only errors and summary
  --version       Show version number
  -h, --help      Show this help message

Skip values:
  json        JSON linting (jsonlint-mod)
  yaml        YAML linting (yamllint)
  markdown    Markdown linting (markdownlint-cli)
  shell       Shell linting (shellcheck)
  python      Python linting (ruff)
  claude      Claude Code plugin validation
  gemini      Gemini CLI extension validation
  pi          Pi package validation
  codex       Codex agent file detection
  opencode    OpenCode agent file detection
  crosscheck  Cross-platform metadata consistency
  skills      SKILL.md frontmatter validation
  skill-name-match  Allow SKILL.md name ≠ folder name

Environment variables:
  VALIDATE_SKIP   Comma-separated checks to skip (merged with --skip)
EOF
}

# --- Pinned tool versions (auditable) ---
JSONLINT_VERSION="${JSONLINT_VERSION:-1.7.6}"
YAMLLINT_VERSION="${YAMLLINT_VERSION:-1.37.0}"
MARKDOWNLINT_VERSION="${MARKDOWNLINT_VERSION:-0.47.0}"
RUFF_VERSION="${RUFF_VERSION:-0.14.14}"
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-2.1.22}"
GEMINI_CLI_VERSION="${GEMINI_CLI_VERSION:-0.26.0}"
TYPESCRIPT_VERSION="${TYPESCRIPT_VERSION:-5.8.3}"

# --- Script location (for bundled defaults) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse arguments ---
SKIP_CHECKS=""
TARGET_DIR=""
VERBOSE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --version)
            echo "agent-validate $VALIDATE_VERSION"
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --skip)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "Error: --skip requires a value (e.g., --skip json,yaml)" >&2
                exit 1
            fi
            if [[ "$2" == /* || "$2" == ./* || "$2" == ../* ]]; then
                echo "Error: --skip value '$2' looks like a path, not check names" >&2
                echo "Usage: validate.sh [--skip CHECKS] [TARGET_DIR]" >&2
                exit 1
            fi
            if [[ -n "$SKIP_CHECKS" ]]; then
                SKIP_CHECKS="${SKIP_CHECKS},$2"
            else
                SKIP_CHECKS="$2"
            fi
            shift 2
            ;;
        --skip=*)
            if [[ -n "$SKIP_CHECKS" ]]; then
                SKIP_CHECKS="${SKIP_CHECKS},${1#--skip=}"
            else
                SKIP_CHECKS="${1#--skip=}"
            fi
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Try 'validate.sh --help' for usage." >&2
            exit 1
            ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                echo "Error: Multiple target directories specified" >&2
                echo "Try 'validate.sh --help' for usage." >&2
                exit 1
            fi
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Merge --skip and VALIDATE_SKIP
if [[ -n "${VALIDATE_SKIP:-}" ]]; then
    if [[ -n "$SKIP_CHECKS" ]]; then
        SKIP_CHECKS="${SKIP_CHECKS},${VALIDATE_SKIP}"
    else
        SKIP_CHECKS="$VALIDATE_SKIP"
    fi
fi

# --- Dependency checks ---
missing_deps=()
command -v jq >/dev/null 2>&1 || missing_deps+=(jq)
command -v npx >/dev/null 2>&1 || missing_deps+=(npx)
if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
    echo "Install them and try again." >&2
    exit 2
fi

# Resolve target directory
if [[ -n "$TARGET_DIR" ]]; then
    cd "$TARGET_DIR"
fi

# --- Output helpers ---
# info: section headers and progress (suppressed by --quiet)
# detail: verbose-only output
info() {
    $QUIET || echo "$@"
}

detail() {
    $VERBOSE && echo "$@" || true
}

# --- Skip check helper ---
should_skip() {
    local check="$1"
    [[ -n "$SKIP_CHECKS" ]] && echo ",$SKIP_CHECKS," | grep -q ",$check,"
}

# --- npx wrapper with network error handling ---
run_npx() {
    local output exit_code=0
    output=$(npx "$@" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "$output"
        if echo "$output" | grep -qiE 'ENOTFOUND|ETIMEDOUT|ECONNREFUSED|network|fetch failed'; then
            echo "Hint: npx failed — check your network connection or try again" >&2
        fi
        return $exit_code
    fi
    [[ -n "$output" ]] && echo "$output"
    return 0
}

# --- Linter config resolution ---
# Resolve after cd so repo-local configs are detected in TARGET_DIR.
# Use repo-local config if present, otherwise fall back to bundled defaults.
yamllint_config_args=()
if [[ ! -f ".yamllint.yml" && ! -f ".yamllint.yaml" && ! -f ".yamllint" ]]; then
    yamllint_config_args=(-c "${SCRIPT_DIR}/defaults/.yamllint.yml")
fi

markdownlint_config_args=()
if [[ ! -f ".markdownlint.json" && ! -f ".markdownlint.jsonc" && ! -f ".markdownlint.yml" && ! -f ".markdownlint.yaml" ]]; then
    markdownlint_config_args=(--config "${SCRIPT_DIR}/defaults/.markdownlint.json")
fi

# --- State ---
errors=0

# --- Tier 1: Generic linting ---

if ! should_skip "json"; then
    info "=== Validating JSON ==="
    json_files=()
    while IFS= read -r -d '' f; do
        json_files+=("$f")
    done < <(find -P . -name "*.json" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" -not -path "*/site-packages/*" -print0)
    if [[ ${#json_files[@]} -gt 0 ]]; then
        printf '%s\0' "${json_files[@]}" | xargs -0 -n1 npx --yes "jsonlint-mod@${JSONLINT_VERSION}" -q || errors=$((errors + 1))
    else
        info "No JSON files found, skipping"
    fi
fi

if ! should_skip "yaml"; then
    info "=== Validating YAML ==="
    yaml_files=()
    while IFS= read -r -d '' f; do
        yaml_files+=("$f")
    done < <(find -P . \( -name "*.yml" -o -name "*.yaml" \) -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" -not -path "*/site-packages/*" -print0)
    if [[ ${#yaml_files[@]} -gt 0 ]]; then
        # Use system yamllint if available (e.g. pip install in CI), otherwise uvx
        yamllint_cmd=(uvx "yamllint@${YAMLLINT_VERSION}")
        if command -v yamllint >/dev/null 2>&1; then
            yamllint_cmd=(yamllint)
            detail "Using system yamllint ($(yamllint --version 2>&1 | head -1))"
        fi
        printf '%s\0' "${yaml_files[@]}" | xargs -0 "${yamllint_cmd[@]}" ${yamllint_config_args[@]+"${yamllint_config_args[@]}"} || errors=$((errors + 1))
    else
        info "No YAML files found, skipping"
    fi
fi

if ! should_skip "markdown"; then
    info "=== Validating Markdown ==="
    npx --yes "markdownlint-cli@${MARKDOWNLINT_VERSION}" '**/*.md' \
        --ignore node_modules --ignore '**/vendor/**' \
        ${markdownlint_config_args[@]+"${markdownlint_config_args[@]}"} || errors=$((errors + 1))
fi

if ! should_skip "shell"; then
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "Warning: shellcheck not found, skipping shell linting" >&2
    else
        info "=== Validating Shell ==="
        shell_files=()
        while IFS= read -r -d '' f; do
            shell_files+=("$f")
        done < <(find -P . -name "*.sh" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" -print0)
        if [[ ${#shell_files[@]} -gt 0 ]]; then
            printf '%s\0' "${shell_files[@]}" | xargs -0 shellcheck || errors=$((errors + 1))
        else
            info "No shell files found, skipping"
        fi
    fi
fi

if ! should_skip "python"; then
    info "=== Validating Python ==="
    py_files=()
    while IFS= read -r -d '' f; do
        py_files+=("$f")
    done < <(find -P . -name "*.py" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" -not -path "*/site-packages/*" -print0)
    if [[ ${#py_files[@]} -gt 0 ]]; then
        # Use system ruff if available, otherwise uvx
        ruff_cmd=(uvx "ruff@${RUFF_VERSION}")
        if command -v ruff >/dev/null 2>&1; then
            ruff_cmd=(ruff)
            detail "Using system ruff ($(ruff --version 2>&1 | head -1))"
        fi
        printf '%s\0' "${py_files[@]}" | xargs -0 "${ruff_cmd[@]}" check || errors=$((errors + 1))
    else
        info "No Python files found, skipping"
    fi
fi

# --- Tier 2: Platform-specific ---

# Claude Code
if ! should_skip "claude"; then
    if [[ -d ".claude-plugin" ]]; then
        info "=== Validating Claude Code plugin ==="
        run_npx --yes "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" plugin validate . || errors=$((errors + 1))

        # Marketplace enumeration
        if [[ -f ".claude-plugin/marketplace.json" ]]; then
            echo "=== Validating marketplace plugins ==="
            local_mp=".claude-plugin/marketplace.json"
            plugin_count=$(jq -e -r '.plugins | length' "$local_mp") || {
                echo "Error: Failed to read plugins array from $local_mp" >&2
                errors=$((errors + 1))
                plugin_count=0
            }
            for ((i = 0; i < plugin_count; i++)); do
                mp_name=$(jq -r ".plugins[$i].name" "$local_mp")
                mp_source=$(jq -r ".plugins[$i].source" "$local_mp")
                mp_strict=$(jq -r "if .plugins[$i].strict == false then \"false\" else \"true\" end" "$local_mp")

                if [[ "$mp_strict" == "false" ]]; then
                    info "Skipping $mp_name (strict: false)"
                    continue
                fi

                info "Validating plugin: $mp_name"
                run_npx --yes "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" plugin validate "$mp_source" || errors=$((errors + 1))

                # Per-plugin Gemini extension
                if ! should_skip "gemini"; then
                    sub_gemini="$mp_source/gemini-extension.json"
                    if [[ -f "$sub_gemini" ]]; then
                        echo "Validating Gemini extension in: $mp_source"
                        run_npx --yes "@google/gemini-cli@${GEMINI_CLI_VERSION}" extensions validate "$mp_source" || errors=$((errors + 1))
                    fi
                fi
            done
        fi
    fi
fi

# Gemini CLI
if ! should_skip "gemini"; then
    if [[ -f "gemini-extension.json" ]]; then
        info "=== Validating Gemini extension ==="
        run_npx --yes "@google/gemini-cli@${GEMINI_CLI_VERSION}" extensions validate . || errors=$((errors + 1))
    fi
fi

# Pi
if ! should_skip "pi"; then
    pi_detected=false
    if [[ -f "package.json" ]] && jq -e '.pi' "package.json" >/dev/null 2>&1; then
        pi_detected=true
    fi
    for d in extensions skills prompts themes; do
        [[ -d "$d" ]] && pi_detected=true
    done

    if $pi_detected; then
        info "=== Validating Pi package ==="

        # Verify package.json pi paths resolve
        if [[ -f "package.json" ]] && jq -e '.pi' "package.json" >/dev/null 2>&1; then
            while IFS= read -r pi_path; do
                [[ -z "$pi_path" || "$pi_path" == "null" ]] && continue
                if [[ ! -e "$pi_path" ]]; then
                    echo "Error: package.json pi path does not resolve: $pi_path" >&2
                    errors=$((errors + 1))
                fi
            done < <(jq -r '.pi | to_entries[] | .value | if type == "array" then .[] else . end | strings' "package.json" 2>/dev/null || true)
        fi

        # Check for pi-package keyword (discovery convention)
        if [[ -f "package.json" ]]; then
            has_pi_keyword=$(jq -r '.keywords // [] | map(select(. == "pi-package")) | length' "package.json")
            if [[ "$has_pi_keyword" == "0" ]]; then
                echo "Warning: package.json missing \"pi-package\" keyword (recommended for Pi package discovery)" >&2
            fi
        fi

        # TypeScript syntax check for extensions
        ts_files=()
        while IFS= read -r -d '' f; do
            ts_files+=("$f")
        done < <(find -P . -path "./extensions/*.ts" -not -path "./node_modules/*" -print0 2>/dev/null)
        if [[ ${#ts_files[@]} -gt 0 ]]; then
            if command -v npx >/dev/null 2>&1; then
                info "Checking TypeScript syntax in extensions/"
                for ts in "${ts_files[@]}"; do
                    tsc_output=$(npx --yes "typescript@${TYPESCRIPT_VERSION}" tsc --noEmit --allowJs --checkJs false "$ts" 2>&1) || {
                        echo "Error: TypeScript syntax error in $ts" >&2
                        echo "$tsc_output" >&2
                        errors=$((errors + 1))
                    }
                done
            fi
        fi
    fi
fi

# Codex
if ! should_skip "codex"; then
    if [[ -f "AGENTS.md" || -f "codex.md" ]]; then
        info "=== Detecting Codex agent files ==="
        for f in AGENTS.md codex.md; do
            if [[ -f "$f" ]]; then
                info "Found: $f"
            fi
        done
    fi
fi

# OpenCode
if ! should_skip "opencode"; then
    if [[ -f "AGENTS.md" ]]; then
        info "=== Detecting OpenCode agent files ==="
        info "Found: AGENTS.md"
    fi
fi

# --- Cross-platform consistency ---

if ! should_skip "crosscheck"; then
    info "=== Cross-checking metadata consistency ==="

    # Manifest paths used throughout this block
    marketplace=".claude-plugin/marketplace.json"

    # Gather metadata from each manifest
    pj_name="" pj_version="" pj_description=""
    ge_name="" ge_version="" ge_description=""
    pi_name="" pi_version="" pi_description=""

    plugin_json=".claude-plugin/plugin.json"
    gemini_json="gemini-extension.json"
    pkg_json="package.json"

    # Field allowlist for plugin.json (used by root and sub-plugin checks)
    # Metadata fields: name, description, version, author, keywords, license, repository, homepage
    # Component path fields: commands, agents, skills, hooks, mcpServers, outputStyles, lspServers
    allowed_fields='["name","description","version","author","keywords","license","repository","homepage","commands","agents","skills","hooks","mcpServers","outputStyles","lspServers"]'

    if [[ -f "$plugin_json" ]]; then
        if ! jq empty "$plugin_json" 2>/dev/null; then
            echo "Error: $plugin_json is not valid JSON" >&2
            errors=$((errors + 1))
        else
            pj_name=$(jq -r '.name // empty' "$plugin_json")
            pj_version=$(jq -r '.version // empty' "$plugin_json")
            pj_description=$(jq -r '.description // empty' "$plugin_json")

            # Field allowlist (structural check, no CLI needed)
            bad_fields=$(jq -r --argjson allowed "$allowed_fields" \
                '[keys[] | select(. as $k | $allowed | index($k) | not)] | .[]' \
                "$plugin_json")
            if [[ -n "$bad_fields" ]]; then
                echo "Error: plugin.json has unrecognized fields: $bad_fields" >&2
                errors=$((errors + 1))
            fi
        fi
    fi

    if [[ -f "$gemini_json" ]]; then
        if ! jq empty "$gemini_json" 2>/dev/null; then
            echo "Error: $gemini_json is not valid JSON" >&2
            errors=$((errors + 1))
        else
            ge_name=$(jq -r '.name // empty' "$gemini_json")
            ge_version=$(jq -r '.version // empty' "$gemini_json")
            ge_description=$(jq -r '.description // empty' "$gemini_json")

            # Gemini extension name format: lowercase alphanumeric with dashes
            if [[ -n "$ge_name" ]] && ! echo "$ge_name" | grep -qE '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
                echo "Error: gemini-extension.json name '$ge_name' must be lowercase alphanumeric with dashes" >&2
                errors=$((errors + 1))
            fi
        fi
    fi

    if [[ -f "$pkg_json" ]] && jq -e '.pi' "$pkg_json" >/dev/null 2>&1; then
        pi_name=$(jq -r '.name // empty' "$pkg_json")
        pi_version=$(jq -r '.version // empty' "$pkg_json")
        pi_description=$(jq -r '.description // empty' "$pkg_json")
    fi

    # Compare plugin.json ↔ gemini-extension.json
    if [[ -n "$pj_name" && -n "$ge_name" && "$pj_name" != "$ge_name" ]]; then
        echo "Error: Name mismatch: plugin.json='$pj_name' gemini-extension.json='$ge_name'" >&2
        errors=$((errors + 1))
    fi
    if [[ -n "$pj_version" && -n "$ge_version" && "$pj_version" != "$ge_version" ]]; then
        echo "Error: Version mismatch: plugin.json='$pj_version' gemini-extension.json='$ge_version'" >&2
        errors=$((errors + 1))
    fi
    if [[ -n "$pj_description" && -n "$ge_description" && "$pj_description" != "$ge_description" ]]; then
        echo "Error: Description mismatch: plugin.json='$pj_description' gemini-extension.json='$ge_description'" >&2
        errors=$((errors + 1))
    fi

    # Compare plugin.json ↔ package.json (pi)
    if [[ -n "$pj_name" && -n "$pi_name" && "$pj_name" != "$pi_name" ]]; then
        echo "Error: Name mismatch: plugin.json='$pj_name' package.json='$pi_name'" >&2
        errors=$((errors + 1))
    fi
    if [[ -n "$pj_version" && -n "$pi_version" && "$pj_version" != "$pi_version" ]]; then
        echo "Error: Version mismatch: plugin.json='$pj_version' package.json='$pi_version'" >&2
        errors=$((errors + 1))
    fi
    if [[ -n "$pj_description" && -n "$pi_description" && "$pj_description" != "$pi_description" ]]; then
        echo "Error: Description mismatch: plugin.json='$pj_description' package.json='$pi_description'" >&2
        errors=$((errors + 1))
    fi

    # Compare gemini-extension.json ↔ package.json (pi)
    if [[ -n "$ge_name" && -n "$pi_name" && "$ge_name" != "$pi_name" ]]; then
        echo "Error: Name mismatch: gemini-extension.json='$ge_name' package.json='$pi_name'" >&2
        errors=$((errors + 1))
    fi
    if [[ -n "$ge_version" && -n "$pi_version" && "$ge_version" != "$pi_version" ]]; then
        echo "Error: Version mismatch: gemini-extension.json='$ge_version' package.json='$pi_version'" >&2
        errors=$((errors + 1))
    fi
    if [[ -n "$ge_description" && -n "$pi_description" && "$ge_description" != "$pi_description" ]]; then
        echo "Error: Description mismatch: gemini-extension.json='$ge_description' package.json='$pi_description'" >&2
        errors=$((errors + 1))
    fi

    # Gemini contextFileName file resolution (handles string or string[])
    if [[ -f "$gemini_json" ]]; then
        info "=== Checking Gemini extension context files ==="
        ctx_type=$(jq -r '.contextFileName | type' "$gemini_json")
        if [[ "$ctx_type" == "string" ]]; then
            context_file=$(jq -r '.contextFileName' "$gemini_json")
            if [[ -n "$context_file" && "$context_file" != "null" ]]; then
                if [[ ! -f "$context_file" ]]; then
                    echo "Error: gemini-extension.json references '$context_file' but file not found" >&2
                    errors=$((errors + 1))
                fi
            else
                if [[ ! -f "GEMINI.md" ]]; then
                    info "Note: No contextFileName and no GEMINI.md (Gemini gets no root context)"
                fi
            fi
        elif [[ "$ctx_type" == "array" ]]; then
            while IFS= read -r context_file; do
                [[ -z "$context_file" || "$context_file" == "null" ]] && continue
                if [[ ! -f "$context_file" ]]; then
                    echo "Error: gemini-extension.json references '$context_file' but file not found" >&2
                    errors=$((errors + 1))
                fi
            done < <(jq -r '.contextFileName[]' "$gemini_json")
        else
            if [[ ! -f "GEMINI.md" ]]; then
                info "Note: No contextFileName and no GEMINI.md (Gemini gets no root context)"
            fi
        fi
    fi

    # Marketplace top-level validation
    if [[ -f "$marketplace" ]]; then
        info "=== Validating marketplace.json structure ==="
        # Required: name
        mp_top_name=$(jq -r '.name // empty' "$marketplace")
        if [[ -z "$mp_top_name" ]]; then
            echo "Error: marketplace.json missing required name field" >&2
            errors=$((errors + 1))
        fi
        # Required: owner.name
        mp_owner_name=$(jq -r '.owner.name // empty' "$marketplace")
        if [[ -z "$mp_owner_name" ]]; then
            echo "Error: marketplace.json missing required owner.name field" >&2
            errors=$((errors + 1))
        fi
        # Required: plugins array
        if ! jq -e '.plugins | type == "array"' "$marketplace" >/dev/null 2>&1; then
            echo "Error: marketplace.json missing required plugins array" >&2
            errors=$((errors + 1))
        fi
        # Validate source paths resolve (relative paths only)
        mp_src_count=$(jq -e -r '.plugins | length' "$marketplace" 2>/dev/null) || mp_src_count=0
        for ((i = 0; i < mp_src_count; i++)); do
            mp_src=$(jq -r ".plugins[$i].source" "$marketplace")
            mp_src_name=$(jq -r ".plugins[$i].name" "$marketplace")
            # Only check relative paths (not URLs, not github: refs)
            if [[ -n "$mp_src" && "$mp_src" != "null" && ! "$mp_src" =~ ^(https?://|github:|git@|npm:) ]]; then
                if [[ "$mp_src" == *..* ]]; then
                    echo "Error: marketplace.json plugin '$mp_src_name' source path contains '..': $mp_src" >&2
                    errors=$((errors + 1))
                elif [[ ! -d "$mp_src" ]]; then
                    echo "Error: marketplace.json plugin '$mp_src_name' source path does not resolve: $mp_src" >&2
                    errors=$((errors + 1))
                fi
            fi
        done
    fi

    # Marketplace cross-checks
    if [[ -f "$marketplace" ]]; then
        info "=== Cross-checking marketplace metadata ==="
        mp_count=$(jq -e -r '.plugins | length' "$marketplace" 2>/dev/null) || mp_count=0
        for ((i = 0; i < mp_count; i++)); do
            mp_name=$(jq -r ".plugins[$i].name" "$marketplace")
            mp_source=$(jq -r ".plugins[$i].source" "$marketplace")
            mp_strict=$(jq -r "if .plugins[$i].strict == false then \"false\" else \"true\" end" "$marketplace")
            mp_version=$(jq -r ".plugins[$i].version // empty" "$marketplace")
            mp_description=$(jq -r ".plugins[$i].description // empty" "$marketplace")

            [[ "$mp_strict" == "false" ]] && continue

            sub_pj="$mp_source/.claude-plugin/plugin.json"
            sub_ge="$mp_source/gemini-extension.json"

            if [[ -f "$sub_pj" ]]; then
                if ! jq empty "$sub_pj" 2>/dev/null; then
                    echo "Error: $mp_name plugin.json is not valid JSON ($sub_pj)" >&2
                    errors=$((errors + 1))
                else
                    sub_pj_name=$(jq -r '.name // empty' "$sub_pj")
                    sub_pj_version=$(jq -r '.version // empty' "$sub_pj")
                    sub_pj_description=$(jq -r '.description // empty' "$sub_pj")

                    if [[ -n "$mp_name" && -n "$sub_pj_name" && "$mp_name" != "$sub_pj_name" ]]; then
                        echo "Error: Name mismatch for $mp_name: marketplace='$mp_name' plugin.json='$sub_pj_name'" >&2
                        errors=$((errors + 1))
                    fi
                    if [[ -n "$mp_version" && -n "$sub_pj_version" && "$mp_version" != "$sub_pj_version" ]]; then
                        echo "Error: Version mismatch for $mp_name: marketplace='$mp_version' plugin.json='$sub_pj_version'" >&2
                        errors=$((errors + 1))
                    fi
                    if [[ -n "$mp_description" && -n "$sub_pj_description" && "$mp_description" != "$sub_pj_description" ]]; then
                        echo "Error: Description mismatch for $mp_name: marketplace='$mp_description' plugin.json='$sub_pj_description'" >&2
                        errors=$((errors + 1))
                    fi

                    # Per-plugin field allowlist
                    sub_bad=$(jq -r --argjson allowed "$allowed_fields" \
                        '[keys[] | select(. as $k | $allowed | index($k) | not)] | .[]' \
                        "$sub_pj")
                    if [[ -n "$sub_bad" ]]; then
                        echo "Error: $mp_name plugin.json has unrecognized fields: $sub_bad" >&2
                        errors=$((errors + 1))
                    fi
                fi
            fi

            if [[ -f "$sub_ge" ]]; then
                if ! jq empty "$sub_ge" 2>/dev/null; then
                    echo "Error: $mp_name gemini-extension.json is not valid JSON ($sub_ge)" >&2
                    errors=$((errors + 1))
                else
                    sub_ge_name=$(jq -r '.name // empty' "$sub_ge")
                    sub_ge_version=$(jq -r '.version // empty' "$sub_ge")
                    sub_ge_description=$(jq -r '.description // empty' "$sub_ge")

                    if [[ -n "$mp_name" && -n "$sub_ge_name" && "$mp_name" != "$sub_ge_name" ]]; then
                        echo "Error: Name mismatch for $mp_name: marketplace='$mp_name' gemini-extension.json='$sub_ge_name'" >&2
                        errors=$((errors + 1))
                    fi
                    if [[ -n "$mp_version" && -n "$sub_ge_version" && "$mp_version" != "$sub_ge_version" ]]; then
                        echo "Error: Version mismatch for $mp_name: marketplace='$mp_version' gemini-extension.json='$sub_ge_version'" >&2
                        errors=$((errors + 1))
                    fi
                    if [[ -n "$mp_description" && -n "$sub_ge_description" && "$mp_description" != "$sub_ge_description" ]]; then
                        echo "Error: Description mismatch for $mp_name: marketplace='$mp_description' gemini-extension.json='$sub_ge_description'" >&2
                        errors=$((errors + 1))
                    fi
                fi
            fi
        done
    fi

    # Marketplace sub-plugin contextFileName resolution (handles string or string[])
    if [[ -f "$marketplace" ]]; then
        info "=== Checking Gemini extension context files (marketplace) ==="
        mp_ctx_count=$(jq -e -r '.plugins | length' "$marketplace" 2>/dev/null) || mp_ctx_count=0
        for ((i = 0; i < mp_ctx_count; i++)); do
            mp_source=$(jq -r ".plugins[$i].source" "$marketplace")
            mp_strict=$(jq -r "if .plugins[$i].strict == false then \"false\" else \"true\" end" "$marketplace")
            [[ "$mp_strict" == "false" ]] && continue

            sub_gemini="$mp_source/gemini-extension.json"
            [[ -f "$sub_gemini" ]] || continue

            mp_name=$(jq -r ".plugins[$i].name" "$marketplace")
            ctx_type=$(jq -r '.contextFileName | type' "$sub_gemini")
            if [[ "$ctx_type" == "string" ]]; then
                sub_ctx=$(jq -r '.contextFileName' "$sub_gemini")
                if [[ -n "$sub_ctx" && "$sub_ctx" != "null" ]]; then
                    if [[ ! -f "$mp_source/$sub_ctx" ]]; then
                        echo "Error: $mp_name gemini-extension.json references '$sub_ctx' but file not found" >&2
                        errors=$((errors + 1))
                    fi
                else
                    if [[ ! -f "$mp_source/GEMINI.md" ]]; then
                        info "Note: $mp_name has no contextFileName and no GEMINI.md (Gemini gets no root context)"
                    fi
                fi
            elif [[ "$ctx_type" == "array" ]]; then
                while IFS= read -r sub_ctx; do
                    [[ -z "$sub_ctx" || "$sub_ctx" == "null" ]] && continue
                    if [[ ! -f "$mp_source/$sub_ctx" ]]; then
                        echo "Error: $mp_name gemini-extension.json references '$sub_ctx' but file not found" >&2
                        errors=$((errors + 1))
                    fi
                done < <(jq -r '.contextFileName[]' "$sub_gemini")
            else
                if [[ ! -f "$mp_source/GEMINI.md" ]]; then
                    info "Note: $mp_name has no contextFileName and no GEMINI.md (Gemini gets no root context)"
                fi
            fi
        done
    fi
fi

# --- SKILL.md validation (Agent Skills specification) ---

if ! should_skip "skills"; then
    # Discover skill directories from all known paths
    skill_dirs=()
    for sd in skills .agents/skills .claude/skills .opencode/skills; do
        [[ -d "$sd" ]] && skill_dirs+=("$sd")
    done
    while IFS= read -r -d '' d; do
        skill_dirs+=("$d")
    done < <(find -P . -path "*/plugins/*/skills" -type d -print0 2>/dev/null)

    # Allowed frontmatter fields (Agent Skills spec)
    allowed_fm_fields="name description license allowed-tools metadata compatibility"
    # Known agent-specific extensions (warning, not error)
    known_extensions="user-invocable argument-hint"

    if [[ ${#skill_dirs[@]} -gt 0 ]]; then
        info "=== Checking SKILL.md (Agent Skills specification) ==="
        while IFS= read -r -d '' skill_file; do
            skill_dir=$(dirname "$skill_file")
            folder_name=$(basename "$skill_dir")

            # Extract all frontmatter lines between --- delimiters
            frontmatter=$(awk '/^---$/{if(++c==2)exit; next} c==1{print}' "$skill_file")

            # --- name: required ---
            fm_name=$(echo "$frontmatter" | awk '/^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}')
            if [[ -z "$fm_name" ]]; then
                echo "Error: No frontmatter 'name' in $skill_file" >&2
                errors=$((errors + 1))
                continue
            fi

            # Name format: max 64 chars
            if [[ ${#fm_name} -gt 64 ]]; then
                echo "Error: Skill name '$fm_name' exceeds 64-char limit (${#fm_name} chars) in $skill_file" >&2
                errors=$((errors + 1))
            fi

            # Name format: lowercase alnum + hyphens only
            if ! echo "$fm_name" | grep -qE '^[a-z0-9-]+$'; then
                echo "Error: Skill name '$fm_name' contains invalid characters (must be lowercase alphanumeric + hyphens) in $skill_file" >&2
                errors=$((errors + 1))
            fi

            # Name format: no leading/trailing hyphens
            if [[ "$fm_name" == -* || "$fm_name" == *- ]]; then
                echo "Error: Skill name '$fm_name' must not start or end with a hyphen in $skill_file" >&2
                errors=$((errors + 1))
            fi

            # Name format: no consecutive hyphens
            if [[ "$fm_name" == *--* ]]; then
                echo "Error: Skill name '$fm_name' must not contain consecutive hyphens in $skill_file" >&2
                errors=$((errors + 1))
            fi

            # Name must match folder (configurable via skip)
            if ! should_skip "skill-name-match" && [[ "$fm_name" != "$folder_name" ]]; then
                # Promoted SKILL.md (sitting in a category dir) gets warning, not error
                grandparent=$(basename "$(dirname "$skill_dir")")
                if [[ "$grandparent" == "skills" || "$grandparent" == "tools" || "$grandparent" == "howto" ]]; then
                    echo "Warning: Promoted SKILL.md name doesn't match folder: frontmatter='$fm_name' folder='$folder_name' in $skill_file" >&2
                else
                    echo "Error: SKILL.md name mismatch: frontmatter='$fm_name' folder='$folder_name' in $skill_file" >&2
                    errors=$((errors + 1))
                fi
            fi

            # --- description: required, non-empty, max 1024 chars ---
            fm_desc=$(echo "$frontmatter" | awk '/^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}')
            if [[ -z "$fm_desc" ]]; then
                echo "Error: No frontmatter 'description' (or empty value) in $skill_file" >&2
                errors=$((errors + 1))
            elif [[ ${#fm_desc} -gt 1024 ]]; then
                echo "Error: Description exceeds 1024-char limit (${#fm_desc} chars) in $skill_file" >&2
                errors=$((errors + 1))
            fi

            # --- compatibility: max 500 chars if present ---
            fm_compat=$(echo "$frontmatter" | awk '/^compatibility:/{sub(/^compatibility:[[:space:]]*/, ""); print; exit}')
            if [[ -n "$fm_compat" && ${#fm_compat} -gt 500 ]]; then
                echo "Error: Compatibility exceeds 500-char limit (${#fm_compat} chars) in $skill_file" >&2
                errors=$((errors + 1))
            fi

            # --- Frontmatter field allowlist ---
            while IFS= read -r field_name; do
                [[ -z "$field_name" ]] && continue
                # Check against spec allowlist
                if ! echo " $allowed_fm_fields " | grep -q " $field_name "; then
                    if echo " $known_extensions " | grep -q " $field_name "; then
                        echo "Warning: '$field_name' is not part of the Agent Skills specification; may not be portable across agents ($skill_file)" >&2
                    else
                        echo "Error: Unexpected frontmatter field '$field_name' in $skill_file (allowed: $allowed_fm_fields)" >&2
                        errors=$((errors + 1))
                    fi
                fi
            done < <(echo "$frontmatter" | grep -E '^[a-zA-Z]' | sed 's/:.*//')

        done < <(find -P "${skill_dirs[@]}" -name "SKILL.md" -print0)

        info "=== Checking for duplicate skill names ==="
        dupes=$(find -P "${skill_dirs[@]}" -name "SKILL.md" -print0 | xargs -0 -I{} \
            awk '/^---$/{if(++c==2)exit} c==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print}' {} \
            | sort | uniq -d)
        if [[ -n "$dupes" ]]; then
            echo "Error: Duplicate skill names found:" >&2
            echo "$dupes" >&2
            errors=$((errors + 1))
        fi
    fi
fi

# --- Extra validation hook ---
if [[ -f "scripts/validate-extra.sh" ]]; then
    info "=== Running extra validation ==="
    bash scripts/validate-extra.sh || errors=$((errors + 1))
fi

# --- Summary ---

# Write structured outputs for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    if [[ $errors -gt 0 ]]; then
        echo "result=fail" >> "$GITHUB_OUTPUT"
    else
        echo "result=pass" >> "$GITHUB_OUTPUT"
    fi
    echo "error-count=$errors" >> "$GITHUB_OUTPUT"
fi

if [[ $errors -gt 0 ]]; then
    echo "Error: Validation failed ($errors error(s); see above)" >&2
    exit 1
fi

info "=== All validations passed ==="
