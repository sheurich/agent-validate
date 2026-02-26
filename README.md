# agent-validate

Cross-agent plugin/extension/skill validation. Works with Claude Code, Gemini CLI, Pi, Codex, and OpenCode.

## What it checks

**Tier 1 — Generic linting** (runs on any repo):

- JSON (`jsonlint-mod`)
- YAML (`yamllint`)
- Markdown (`markdownlint-cli`)
- Shell (`shellcheck`)
- Python (`ruff`)

**Tier 2 — Platform-specific** (auto-detected by file presence):

- `.claude-plugin/` → `claude plugin validate`, plugin.json field allowlist, marketplace.json structure
- `gemini-extension.json` → `gemini extensions validate`, name format, contextFileName resolution
- `package.json` with `.pi` key → path resolution, keyword check, TypeScript syntax
- `AGENTS.md` / `codex.md` → Codex/OpenCode detection

**Cross-platform** — metadata consistency across manifests (name, version, description), SKILL.md frontmatter validation, duplicate skill detection.

## Usage

### Script

```sh
./validate.sh [--skip CHECKS] [TARGET_DIR]
```

Skip individual checks with a comma-separated list:

```sh
./validate.sh --skip json,yaml,claude /path/to/plugin
```

Available skip values: `json`, `yaml`, `markdown`, `shell`, `python`, `claude`, `gemini`, `pi`, `codex`, `opencode`, `crosscheck`, `skills`.

The `VALIDATE_SKIP` environment variable works the same way and merges with `--skip`.

### GitHub Action

```yaml
- uses: sheurich/agent-validate@v1
  with:
    path: "."        # default: repo root
    skip: ""         # default: none
```

All tool versions are pinnable via inputs (`jsonlint-version`, `yamllint-version`, `markdownlint-version`, `ruff-version`, `claude-code-version`, `gemini-cli-version`).

### Extra validation hook

If `scripts/validate-extra.sh` exists in the target directory, it runs after all built-in checks. A nonzero exit code fails the overall validation.

## Configuration

Linter configs are auto-discovered from the target repo. If none exist, bundled defaults from `defaults/` are used:

- `.yamllint.yml` / `.yamllint.yaml` / `.yamllint`
- `.markdownlint.json` / `.markdownlint.jsonc` / `.markdownlint.yml` / `.markdownlint.yaml`

## Design

- **Zero-config**: runs with no setup against any agent plugin/extension/skill repo
- **Auto-detect**: platforms detected by file presence, not flags
- **Auditable**: all tool versions pinned and overridable; GitHub Actions use full SHA pins
- **System-first**: prefers system-installed `yamllint` and `ruff` before falling back to `uvx`

## Spec conformance

Vendored platform specs live in `skills/spec-conformance/`. The SKILL.md there documents what validate.sh checks against each upstream spec, tracks drift, and tells agents how to verify changes. See that file when modifying validation logic.
