# agent-validate Design

**Goal:** Provide cross-agent plugin/extension/skill validation as a local script and GitHub composite action.

**Architecture:** A single `validate.sh` script auto-detects which agent platforms are present (Claude Code, Gemini CLI, Pi, Codex, OpenCode) and runs applicable checks. A GitHub composite `action.yml` wraps the script for CI. Zero configuration by default; consumer repos override via env vars, `--skip`, and local linter configs.

**Platforms:** Claude Code, Gemini CLI, Pi, Codex, OpenCode — all at equal depth.

## Validation Tiers

### Tier 1: Generic Linting
- JSON: `jsonlint-mod` on all `*.json`
- YAML: `yamllint` on all `*.yml`/`*.yaml`
- Markdown: `markdownlint-cli` on all `*.md`
- Shell: `shellcheck` on all `*.sh`
- Python: `ruff` on all `*.py`

### Tier 2: Platform-Specific
- **Claude Code:** `claude plugin validate .`, plugin.json field allowlist, marketplace enumeration
- **Gemini CLI:** `gemini extensions validate .`, contextFileName resolution, GEMINI.md fallback check
- **Pi:** verify `pi` key in package.json or convention dirs exist, path resolution, TypeScript syntax
- **Codex/OpenCode:** AGENTS.md/codex.md detection → markdown lint
- **Cross-platform:** name/version/description consistency across manifests
- **SKILL.md:** frontmatter validation, name-folder match, duplicate detection

### Consumer Overrides
- Repo-local linter configs take precedence over bundled defaults
- Env vars: `JSONLINT_VERSION`, `YAMLLINT_VERSION`, `MARKDOWNLINT_VERSION`, `RUFF_VERSION`, `CLAUDE_CODE_VERSION`, `GEMINI_CLI_VERSION`
- `--skip` flag / `VALIDATE_SKIP` env var (comma-separated: `json,yaml,markdown,shell,python,claude,gemini,pi,codex,opencode,crosscheck,skills`)
- Optional `scripts/validate-extra.sh` hook

### Security Model
- `set -euo pipefail`, no eval, `-print0`/`xargs -0`
- Pinned tool versions as auditable variables at top of script
- `permissions: contents: read` in action.yml
- SHA-pinned action references in workflow

## Output Format
- `=== Validating X ===` section headers
- `Error:` messages to stderr
- Warnings don't fail the build
- Exit 0 (pass) or 1 (fail)
- No color codes (CI-safe)
