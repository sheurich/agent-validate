#!/usr/bin/env bash
# update-versions.sh — Check for new CLI versions and upstream spec changes.
#
# Fetches latest npm versions for coding-agent CLIs, downloads upstream
# specs, extracts the Gemini extension field allowlist, and applies
# updates to all pinned locations.  Writes a Markdown summary to
# /tmp/update-summary.md for use as a PR body.
#
# Exit codes:
#   0  Changes were made (or would be made in --dry-run)
#   1  Everything is already current
#   2  Missing required tool or other fatal error
#
# Usage:
#   ./update-versions.sh            # apply updates in-place
#   ./update-versions.sh --dry-run  # show what would change without writing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REFS_DIR="$REPO_ROOT/skills/spec-conformance/references"
SUMMARY_FILE="/tmp/update-summary.md"

changes=()

# --- dependency check -------------------------------------------------------

missing=()
for cmd in npm git curl jq awk sed; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: missing required tools: ${missing[*]}" >&2
    echo "Install them and retry. On macOS: brew install ${missing[*]}" >&2
    exit 2
fi

# --- helpers ----------------------------------------------------------------

info()  { echo "  $*"; }
changed() { changes+=("$1"); }

# npm_latest PACKAGE
#   Print the latest version of an npm package.
npm_latest() {
    npm view "$1" version 2>/dev/null
}

# git_head_sha REPO_URL
#   Print the HEAD SHA of a remote repository.
git_head_sha() {
    git ls-remote "$1" HEAD 2>/dev/null | awk '{print $1}'
}

# sed_inplace EXPRESSION FILE
#   Portable in-place sed (macOS vs GNU).
sed_inplace() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$1" "$2"        # GNU
    else
        sed -i '' "$1" "$2"     # macOS
    fi
}

# --- 1. CLI version bumps ---------------------------------------------------

echo "=== Checking CLI versions ==="

cur_claude=$(grep 'CLAUDE_CODE_VERSION:-' "$REPO_ROOT/validate.sh" | head -1 \
    | sed 's/.*CLAUDE_CODE_VERSION:-//; s/["}].*//')
cur_gemini=$(grep 'GEMINI_CLI_VERSION:-' "$REPO_ROOT/validate.sh" | head -1 \
    | sed 's/.*GEMINI_CLI_VERSION:-//; s/["}].*//')
cur_skills=$(grep -oE 'skills-ref@[0-9][0-9.]*' "$REPO_ROOT/.github/workflows/cli-regression.yml" | head -1 | sed 's/skills-ref@//')

new_claude=$(npm_latest "@anthropic-ai/claude-code")
new_gemini=$(npm_latest "@google/gemini-cli")
new_skills=$(npm_latest "skills-ref")

# Use parallel indexed arrays instead of associative arrays (Bash 3.2 compat).
pkg_names=(claude gemini skills)
pkg_labels=("@anthropic-ai/claude-code" "@google/gemini-cli" "skills-ref")
pkg_cur=("$cur_claude" "$cur_gemini" "$cur_skills")
pkg_new=("$new_claude" "$new_gemini" "$new_skills")

for i in "${!pkg_names[@]}"; do
    cur="${pkg_cur[$i]}"
    new="${pkg_new[$i]}"
    label="${pkg_labels[$i]}"
    if [[ "$cur" != "$new" ]]; then
        info "$label: $cur → $new"
        changed "$label $cur → $new"
    else
        info "$label: $cur (current)"
    fi
done

if ! $DRY_RUN; then
    # validate.sh — header comments
    sed_inplace "s|claude-code version (default: ${cur_claude})|claude-code version (default: ${new_claude})|" "$REPO_ROOT/validate.sh"
    sed_inplace "s|gemini-cli version (default: ${cur_gemini})|gemini-cli version (default: ${new_gemini})|" "$REPO_ROOT/validate.sh"
    # validate.sh — default assignments
    sed_inplace "s|CLAUDE_CODE_VERSION:-${cur_claude}|CLAUDE_CODE_VERSION:-${new_claude}|" "$REPO_ROOT/validate.sh"
    sed_inplace "s|GEMINI_CLI_VERSION:-${cur_gemini}|GEMINI_CLI_VERSION:-${new_gemini}|" "$REPO_ROOT/validate.sh"
    # action.yml — input defaults (target the line after the description)
    sed_inplace "s|default: \"${cur_claude}\"|default: \"${new_claude}\"|" "$REPO_ROOT/action.yml"
    sed_inplace "s|default: \"${cur_gemini}\"|default: \"${new_gemini}\"|" "$REPO_ROOT/action.yml"
    # cli-regression.yml — npx pins
    sed_inplace "s|claude-code@${cur_claude}|claude-code@${new_claude}|g" "$REPO_ROOT/.github/workflows/cli-regression.yml"
    sed_inplace "s|gemini-cli@${cur_gemini}|gemini-cli@${new_gemini}|g" "$REPO_ROOT/.github/workflows/cli-regression.yml"
    sed_inplace "s|skills-ref@${cur_skills}|skills-ref@${new_skills}|g" "$REPO_ROOT/.github/workflows/cli-regression.yml"
fi

# --- 2. Upstream spec sync --------------------------------------------------

echo ""
echo "=== Checking upstream specs ==="

FRESHNESS="$REPO_ROOT/.github/workflows/spec-freshness.yml"
GH_RAW="https://raw.githubusercontent.com"

# Read current SHA pins.
cur_pi_sha=$(grep -oE 'PI_MONO_SHA: "[a-f0-9]+"' "$FRESHNESS" | grep -oE '[a-f0-9]{40}')
cur_gemini_sha=$(grep -oE 'GEMINI_CLI_SHA: "[a-f0-9]+"' "$FRESHNESS" | grep -oE '[a-f0-9]{40}')
cur_agentskills_sha=$(grep -oE 'AGENTSKILLS_SHA: "[a-f0-9]+"' "$FRESHNESS" | grep -oE '[a-f0-9]{40}')

new_pi_sha=$(git_head_sha "https://github.com/badlogic/pi-mono.git")
new_gemini_sha=$(git_head_sha "https://github.com/google-gemini/gemini-cli.git")
new_agentskills_sha=$(git_head_sha "https://github.com/agentskills/agentskills.git")

# Sync each upstream source.
sync_spec() {
    local label="$1" cur_sha="$2" new_sha="$3" url="$4" local_file="$5"
    if [[ "$cur_sha" == "$new_sha" ]]; then
        info "$label: current"
        return 0
    fi
    info "$label: ${cur_sha:0:7} → ${new_sha:0:7}"
    changed "$label ${cur_sha:0:7} → ${new_sha:0:7}"
    if ! $DRY_RUN; then
        curl -fsSL "$url" -o "$local_file"
    fi
}

sync_spec "pi-mono (README)" "$cur_pi_sha" "$new_pi_sha" \
    "${GH_RAW}/badlogic/pi-mono/${new_pi_sha}/packages/coding-agent/README.md" \
    "$REFS_DIR/pi-readme.md"
sync_spec "pi-mono (skills.md)" "$cur_pi_sha" "$new_pi_sha" \
    "${GH_RAW}/badlogic/pi-mono/${new_pi_sha}/packages/coding-agent/docs/skills.md" \
    "$REFS_DIR/pi-skills.md"
sync_spec "gemini-cli (reference.md)" "$cur_gemini_sha" "$new_gemini_sha" \
    "${GH_RAW}/google-gemini/gemini-cli/${new_gemini_sha}/docs/extensions/reference.md" \
    "$REFS_DIR/gemini-extension-reference.md"
sync_spec "gemini-cli (extension.ts)" "$cur_gemini_sha" "$new_gemini_sha" \
    "${GH_RAW}/google-gemini/gemini-cli/${new_gemini_sha}/packages/cli/src/config/extension.ts" \
    "$REFS_DIR/gemini-extension-config.ts"
sync_spec "agentskills (specification)" "$cur_agentskills_sha" "$new_agentskills_sha" \
    "${GH_RAW}/agentskills/agentskills/${new_agentskills_sha}/docs/specification.mdx" \
    "$REFS_DIR/agentskills-specification.mdx"

# Update SHA pins in spec-freshness.yml.
if ! $DRY_RUN; then
    sed_inplace "s|PI_MONO_SHA: \"${cur_pi_sha}\"|PI_MONO_SHA: \"${new_pi_sha}\"|" "$FRESHNESS"
    sed_inplace "s|GEMINI_CLI_SHA: \"${cur_gemini_sha}\"|GEMINI_CLI_SHA: \"${new_gemini_sha}\"|" "$FRESHNESS"
    sed_inplace "s|AGENTSKILLS_SHA: \"${cur_agentskills_sha}\"|AGENTSKILLS_SHA: \"${new_agentskills_sha}\"|" "$FRESHNESS"
fi

# Claude specs — no SHA pin, always re-fetch and compare by hash.
for spec in plugins-reference plugin-marketplaces; do
    remote_url="https://code.claude.com/docs/en/${spec}.md"
    local_file="$REFS_DIR/claude-${spec}.md"
    tmp_file="/tmp/claude-${spec}.md"

    if curl -fsSL "$remote_url" -o "$tmp_file" 2>/dev/null; then
        if [[ -f "$local_file" ]] && cmp -s "$tmp_file" "$local_file"; then
            info "claude (${spec}.md): current"
        else
            info "claude (${spec}.md): updated"
            changed "claude ${spec}.md"
            if ! $DRY_RUN; then
                cp "$tmp_file" "$local_file"
            fi
        fi
        rm -f "$tmp_file"
    else
        info "claude (${spec}.md): fetch failed, skipping"
    fi
done

# --- 3. Gemini extension field allowlist ------------------------------------

echo ""
echo "=== Updating Gemini extension field allowlist ==="

ts_file="$REFS_DIR/gemini-extension-config.ts"
if [[ -f "$ts_file" ]]; then
    # Extract top-level field names from ExtensionConfig interface.
    # Only match lines indented exactly one level (2 spaces) to skip nested
    # fields like plan.directory.
    fields=$(sed -n '/^export interface ExtensionConfig/,/^}/p' "$ts_file" \
        | grep -E '^  [a-z]\w*[\?]?\s*:' \
        | sed 's/^[[:space:]]*//; s/[?]*[[:space:]]*:.*//' \
        | sort)
    # Always include "description" (in reference docs but not TS interface).
    fields=$(printf '%s\ndescription' "$fields" | sort -u)
    # Format as JSON array.
    new_allowlist=$(echo "$fields" | jq -R . | jq -sc .)

    cur_allowlist=$(grep "gemini_allowed_fields=" "$REPO_ROOT/validate.sh" | head -1 \
        | sed "s/.*gemini_allowed_fields='//; s/'.*//")

    if [[ "$cur_allowlist" != "$new_allowlist" ]]; then
        info "allowlist: $cur_allowlist → $new_allowlist"
        changed "Gemini allowlist updated"
        if ! $DRY_RUN; then
            # Use awk for clean replacement — JSON arrays are hard to escape for sed.
            awk -v new="$new_allowlist" '
                /gemini_allowed_fields=/ && !done {
                    sub(/\047\[.*\]\047/, "\047" new "\047")
                    done = 1
                }
                { print }
            ' "$REPO_ROOT/validate.sh" > "$REPO_ROOT/validate.sh.tmp" \
                && mv "$REPO_ROOT/validate.sh.tmp" "$REPO_ROOT/validate.sh" \
                && chmod +x "$REPO_ROOT/validate.sh"
        fi
    else
        info "allowlist: current ($new_allowlist)"
    fi
else
    info "gemini-extension-config.ts not found, skipping allowlist update"
fi

# --- 4. Summary -------------------------------------------------------------

echo ""
if [[ ${#changes[@]} -eq 0 ]]; then
    echo "✅ Everything is already current."
    rm -f "$SUMMARY_FILE"
    exit 1
fi

if $DRY_RUN; then
    echo "🔍 ${#changes[@]} update(s) would be applied (dry-run, no files written)."
else
    echo "📝 ${#changes[@]} update(s) applied."
fi

# Write PR body summary.
{
    echo "## Automated version bump and spec sync"
    echo ""
    echo "Updates applied by [\`update-versions.sh\`](update-versions.sh):"
    echo ""
    for c in "${changes[@]}"; do
        echo "- $c"
    done
    echo ""
    echo "All tests passed before PR creation."
} > "$SUMMARY_FILE"

exit 0
