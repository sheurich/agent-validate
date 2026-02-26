# agent-validate

Cross-agent plugin/extension/skill validation for Claude Code, Gemini CLI, Pi, Codex, and OpenCode.

Runs as a local script or a GitHub composite action. Zero configuration by default — auto-detects which platforms are present and runs applicable checks.

## Quick start

### GitHub Actions

```yaml
- uses: sheurich/agent-validate@v1
```

### Local

```bash
# Clone at a pinned ref
gh repo clone sheurich/agent-validate -- --branch v1 /path/to/agent-validate

# Run
/path/to/agent-validate/validate.sh
```

Or add as a git submodule:

```bash
git submodule add -b v1 https://github.com/sheurich/agent-validate.git tools/agent-validate
./tools/agent-validate/validate.sh
```

## What it checks

### Tier 1: Generic linting

| Check | Tool | Files |
|-------|------|-------|
| JSON | jsonlint-mod | `*.json` |
| YAML | yamllint | `*.yml`, `*.yaml` |
| Markdown | markdownlint-cli | `*.md` |
| Shell | shellcheck | `*.sh` |
| Python | ruff | `*.py` |

### Tier 2: Platform-specific

| Platform | Detection | Checks |
|----------|-----------|--------|
| Claude Code | `.claude-plugin/` | `claude plugin validate`, field allowlist, marketplace enumeration |
| Gemini CLI | `gemini-extension.json` | `gemini extensions validate`, contextFileName resolution |
| Pi | `package.json` with `pi` key or `extensions/`/`skills/`/`prompts/`/`themes/` dirs | path resolution, TypeScript syntax |
| Codex | `AGENTS.md` or `codex.md` | markdown lint |
| OpenCode | `AGENTS.md` | markdown lint |

### Cross-platform

- Name, version, and description consistency across `plugin.json`, `gemini-extension.json`, and `package.json`
- Marketplace metadata cross-checking when `.claude-plugin/marketplace.json` exists

### SKILL.md frontmatter

- Required `name` and `description` fields
- `name` must match containing folder
- Duplicate skill name detection
- Promoted SKILL.md files (in category directories) get warnings instead of errors

## Configuration

### Skipping checks

Use `--skip` or `VALIDATE_SKIP` (comma-separated):

```bash
./validate.sh --skip claude,gemini
VALIDATE_SKIP=python,shell ./validate.sh
```

Available checks: `json`, `yaml`, `markdown`, `shell`, `python`, `claude`, `gemini`, `pi`, `codex`, `opencode`, `crosscheck`, `skills`

### Tool versions

Override pinned versions via environment variables:

| Variable | Default |
|----------|---------|
| `JSONLINT_VERSION` | 1.7.6 |
| `YAMLLINT_VERSION` | 1.37.0 |
| `MARKDOWNLINT_VERSION` | 0.47.0 |
| `RUFF_VERSION` | 0.14.14 |
| `CLAUDE_CODE_VERSION` | 2.1.22 |
| `GEMINI_CLI_VERSION` | 0.26.0 |

### Linter configs

Place repo-local configs to override bundled defaults:

- `.yamllint.yml` / `.yamllint.yaml` / `.yamllint`
- `.markdownlint.json` / `.markdownlint.jsonc` / `.markdownlint.yml`

### Extra validation

Add `scripts/validate-extra.sh` to your repo. It runs after all built-in checks.

### Composite action inputs

```yaml
- uses: sheurich/agent-validate@v1
  with:
    path: "."                        # Directory to validate
    skip: ""                         # Comma-separated checks to skip
    jsonlint-version: "1.7.6"
    yamllint-version: "1.37.0"
    markdownlint-version: "0.47.0"
    ruff-version: "0.14.14"
    claude-code-version: "2.1.22"
    gemini-cli-version: "0.26.0"
```

## Output format

- `=== Validating X ===` section headers
- `Error:` messages to stderr
- Warnings don't fail the build
- Exit 0 (all checks pass) or exit 1 (any check fails)
- No color codes (CI-safe)

## Security

- `set -euo pipefail`, no `eval`
- `-print0` / `xargs -0` for safe filename handling
- Pinned tool versions as auditable variables at top of script
- SHA-pinned action references in workflows
- `permissions: contents: read` in composite action
- Local invocation via git submodule or `gh repo clone` at pinned ref — no curl-pipe-bash

## License

MIT
