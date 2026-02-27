# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `SECURITY.md` with vulnerability reporting and trust model documentation
- Test harness `--filter` pattern argument for running a subset of tests
- Pinned shellcheck v0.11.0 in CI via `ludeeus/action-shellcheck` (SHA-pinned)
- `argument-hint` frontmatter field accepted with portability warning (Pi extension)

### Fixed

- `action.yml`: use `env:` for all user-controlled inputs (prevents shell injection)
- `--skip` without a value or with a path-like value now errors instead of silently
  consuming the next argument
- JSON and YAML linters now exclude `.venv/` and `site-packages/` (consistent with
  shell and Python linters)
- TypeScript checker shows diagnostics instead of suppressing stderr with `2>/dev/null`
- TypeScript pinned to `5.8.3` instead of `@latest` for reproducible results
- shellcheck availability checked before use; missing shellcheck produces a clear
  warning instead of a confusing xargs error
- Sub-plugin JSON files validated with `jq empty` before field extraction; malformed
  sub-plugin JSON now reports an error instead of aborting the script
- `SCRIPT_DIR` with spaces no longer breaks config resolution (array-based config
  args replace word-splitting functions)

### Changed

- Codex/OpenCode sections say "Detecting" instead of "Validating" (no validation
  is performed; the old banner was misleading)
- CHANGELOG: folded `[Unreleased]` content into `[1.0.0]` versioned heading

## [1.0.0] - 2026-02-26

### Added

- `--help` / `-h` flag with usage and available skip values
- Dependency checks at startup (jq, npx required; exit 2 if missing)
- SKILL.md validation aligned with [Agent Skills specification](https://agentskills.io/docs/specification):
  name format (max 64 chars, lowercase alnum + hyphens, no leading/trailing/consecutive hyphens),
  description non-empty and max 1024 chars, compatibility max 500 chars, frontmatter field allowlist
- `user-invocable` frontmatter field accepted with portability warning
- `skill-name-match` skip value for consumers with promoted skills
- Additional skill discovery paths: `.agents/skills/`, `.claude/skills/`, `.opencode/skills/`
- Vendored canonical Agent Skills specification (`agentskills-specification.mdx`)
- `--verbose` and `--quiet` flags
- macOS CI matrix row
- ruff installed via pip in action.yml (no uvx dependency)
- `result` and `error-count` action outputs
- `CONTRIBUTING.md`
- `--version` flag
- broken-shell and broken-python test fixtures
- Tests for unknown flags, `--skip=value` form, multiple positional args, dependency checks
- Reject `..` in marketplace source paths
- Action outputs (`result`, `error-count`) written directly via `GITHUB_OUTPUT` in validate.sh
- Failing-fixture CI job verifies action outputs on validation failure

### Fixed

- `find -P` used on all find invocations to avoid symlink loops
- `--skip a --skip b` now concatenates instead of overwriting first value
- Action output parsing no longer relies on scraping stderr (moved to validate.sh)
- Malformed JSON in crosscheck increments errors instead of crashing
- Pi path regex no longer matches non-path strings (e.g. metadata values)
- Multiple positional directory arguments rejected with error

## [v1] - 2026-02-26

Initial release. 38 tests passing.

- Tier 1 linting: JSON, YAML, Markdown, Shell, Python
- Tier 2 platform validation: Claude Code, Gemini CLI, Pi, Codex, OpenCode
- Cross-platform metadata consistency checks
- SKILL.md frontmatter validation and duplicate detection
- marketplace.json structure and cross-checks
- Gemini contextFileName resolution (string and array)
- Pi path resolution and keyword check
- Extra validation hook (`scripts/validate-extra.sh`)
- GitHub composite action with pinned tool versions
