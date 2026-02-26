# Copilot Code Review Instructions

When reviewing changes to `validate.sh`, `action.yml`, or test fixtures in this repository, read `skills/spec-conformance/SKILL.md` and the vendored references in `skills/spec-conformance/references/` before approving.

## Architecture

- **Zero-config**: consumers run `./validate.sh [dir]` or use the GitHub Action with no setup
- **Auto-detect**: platforms are detected by file presence (`.claude-plugin/`, `gemini-extension.json`, `package.json` with `.pi`, `AGENTS.md`)
- **Tiered**: tier 1 (generic linting) runs unconditionally; tier 2 (platform CLI tools) runs only when platform files exist
- **SHA-pinned**: all GitHub Actions in CI use full commit SHAs, not tags
- **Bundled defaults**: `defaults/.yamllint.yml` and `defaults/.markdownlint.json` are used unless the target repo provides its own config
- **System-first tool detection**: yamllint and ruff prefer system-installed versions before falling back to `uvx`

## Review Checklist

For changes to validation logic:

- Does the allowlist in `validate.sh` match what the upstream spec documents?
- Are new fields tested (both accept and reject)?
- Do error messages include the file and field that failed?
- Are marketplace sub-plugin checks consistent with root-level checks?

For changes to `action.yml`:

- Are action pins full 40-character SHAs with a comment showing the version?
- Do input defaults match the pinned versions in `validate.sh`?

For test changes:

- Does every new validation check have both a pass and fail test?
- Do `assert_fail_stderr` patterns match the actual error messages in validate.sh?
- Are fixture JSON files valid (run `jq . <file>` to verify)?

## Known Remaining Drift

See the "Known Drift" section in `skills/spec-conformance/SKILL.md` for items where validate.sh intentionally or accidentally diverges from upstream specs.
