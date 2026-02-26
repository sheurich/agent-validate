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

**Cross-platform** — metadata consistency across manifests (name, version, description), SKILL.md validation per the [Agent Skills specification](https://agentskills.io/docs/specification) (name format, description, frontmatter allowlist, discovery paths), duplicate skill detection.

## Usage

### Script

```sh
./validate.sh [--skip CHECKS] [TARGET_DIR]
```

Skip individual checks with a comma-separated list:

```sh
./validate.sh --skip json,yaml,claude /path/to/plugin
```

Multiple `--skip` flags are concatenated:

```sh
./validate.sh --skip json,yaml --skip claude /path/to/plugin
```

Available skip values: `json`, `yaml`, `markdown`, `shell`, `python`, `claude`, `gemini`, `pi`, `codex`, `opencode`, `crosscheck`, `skills`, `skill-name-match`.

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

If `scripts/validate-extra.sh` exists in the target directory, it runs after
all built-in checks. A nonzero exit code fails the overall validation.

The hook runs via `bash scripts/validate-extra.sh` in the target directory.
It inherits the environment but receives no arguments. Use it for
project-specific checks that don't belong in the shared validator.

## Configuration

Linter configs are auto-discovered from the target repo. If none exist, bundled defaults from `defaults/` are used:

- `.yamllint.yml` / `.yamllint.yaml` / `.yamllint`
- `.markdownlint.json` / `.markdownlint.jsonc` / `.markdownlint.yml` / `.markdownlint.yaml`

## Design

- **Zero-config**: runs with no setup against any agent plugin/extension/skill repo
- **Auto-detect**: platforms detected by file presence, not flags
- **Auditable**: all tool versions pinned and overridable; GitHub Actions use full SHA pins
- **System-first**: prefers system-installed `yamllint` and `ruff` before falling back to `uvx`

## Supply chain

All npm packages are invoked via `npx --yes` with pinned versions. GitHub
Actions in `action.yml` and CI workflows use full SHA pins. Tool versions
default to audited values and are overridable via environment variables or
action inputs.

The `validate-extra.sh` hook executes arbitrary shell code from the target
repo. Treat it the same as any other script in a repository you've chosen
to validate — review it before running against untrusted repos.

## Troubleshooting

**`npx` fails with network errors**
Check connectivity. Tier 2 checks (`claude`, `gemini`) download large
packages on first run. Use `--skip claude,gemini` to run structural checks
offline.

**`jq` or `npx` not found**
validate.sh requires `jq` and `npx` (Node.js). Install them:

```sh
# macOS
brew install jq node

# Ubuntu/Debian
sudo apt-get install jq nodejs npm
```

**SKILL.md name mismatch on promoted skills**
Skills whose grandparent directory is `skills`, `tools`, or `howto` get a
warning instead of an error. Use `--skip skill-name-match` to suppress the
name-folder check entirely.

**shellcheck / ruff not found**
Shell and Python linting require `shellcheck` and `ruff` respectively. If
neither the system binary nor `uvx` is available, the check fails.

## Spec conformance

Vendored platform specs live in `skills/spec-conformance/`. The SKILL.md there documents what validate.sh checks against each upstream spec, tracks drift, and tells agents how to verify changes. See that file when modifying validation logic.
