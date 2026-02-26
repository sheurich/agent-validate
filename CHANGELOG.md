# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
