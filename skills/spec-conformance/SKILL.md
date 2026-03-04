---
name: spec-conformance
description: Verify validate.sh checks match upstream platform specs. Use when reviewing changes to validation logic, updating allowed fields, or checking for spec drift.
---

# Spec Conformance

This skill contains vendored specifications for every platform agent-validate checks. Use it to verify that validate.sh matches what upstream projects actually require.

## How to Use

When reviewing a PR that changes validation logic in validate.sh:

1. Read the relevant spec section below
2. Compare against the code being changed
3. Flag any drift (validate.sh checks something the spec doesn't require, or misses something it does)

When updating validate.sh for a new upstream spec version:

1. Fetch the latest spec from the source URL listed in each section
2. Update the vendored spec in `references/`
3. Update validate.sh to match
4. Update this file's "Last verified" date

## Platform Specs

### Agent Skills Specification (SKILL.md)

**Source:** `https://agentskills.io/docs/specification` / `https://raw.githubusercontent.com/agentskills/agentskills/main/docs/specification.mdx`
**Reference validator:** `https://github.com/agentskills/agentskills/tree/main/skills-ref`
**Vendored:** `references/agentskills-specification.mdx`
**Last verified:** 2026-02-26

This is the canonical source of truth for SKILL.md validation. The Agent Skills open standard defines:

Required frontmatter: `name`, `description`.

Optional frontmatter: `license`, `compatibility`, `metadata`, `allowed-tools`.

**Field allowlist:** Only `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility` are permitted. The reference validator (`skills-ref validate`) rejects any other fields.

**Name constraints:** 1–64 chars, lowercase alphanumeric + hyphens, no leading/trailing hyphens, no consecutive hyphens, must match parent directory name.

**Description constraints:** Non-empty string, max 1024 chars.

**Compatibility constraints:** Max 500 chars if present.

**What validate.sh checks:** All of the above, plus:
- `user-invocable` accepted with a portability warning (used by Claude Code for slash menu visibility; not in the spec)
- Name-folder mismatch configurable: error by default, skippable via `--skip skill-name-match`
- Promoted skills (grandparent is `skills`, `tools`, or `howto`) get warnings instead of errors for name mismatch
- Scans: `skills/`, `.agents/skills/`, `.claude/skills/`, `.opencode/skills/`, `plugins/*/skills/`
- Duplicate name detection across all discovered skills

### Claude Code plugin.json

**Source:** `https://code.claude.com/docs/en/plugins-reference.md`
**Vendored:** `references/claude-plugins-reference.md`
**Last verified:** 2026-02-26

Required fields: `name` only (manifest itself is optional).

Metadata fields (all optional): `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`.

Component path fields (all optional): `commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`. Each accepts `string|array` (some also accept `object` for inline config).

**What validate.sh checks:** Field allowlist covering all metadata and component path fields. Rejects any key not in the allowlist. Also runs `claude plugin validate` for structural checks (tier 2). Handles malformed JSON gracefully (error, not crash).

### Claude Code marketplace.json

**Source:** `https://code.claude.com/docs/en/plugin-marketplaces.md`
**Vendored:** `references/claude-plugin-marketplaces.md`
**Last verified:** 2026-02-26

Required top-level fields: `name`, `owner` (with required `owner.name`), `plugins` array.

Optional top-level: `metadata.description`, `metadata.version`, `metadata.pluginRoot`.

Per-plugin required: `name`, `source`.

Per-plugin optional: `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`, `category`, `tags`, `strict`, `commands`, `agents`, `hooks`, `mcpServers`, `lspServers`.

`strict` (boolean, default true): when false, plugin.json is not the authority for component definitions.

Source types: relative paths, GitHub repos (`github:owner/repo`), git URLs, npm packages. Only relative paths are validated for resolution.

**What validate.sh checks:** Validates `name`, `owner.name`, and `plugins` array are present. Rejects `source` paths containing `..`. Checks relative `source` paths resolve to directories. Cross-checks per-plugin `name`, `version`, `description` against sub-plugin manifests. Runs `claude plugin validate` on each non-strict-false sub-plugin.

### Gemini CLI gemini-extension.json

**Source:** `https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md`
**TypeScript interface:** `https://github.com/google-gemini/gemini-cli/blob/main/packages/a2a-server/src/config/extension.ts`
**Vendored:** `references/gemini-extension-reference.md`, `references/gemini-extension-config.ts`
**Last verified:** 2026-02-26

Interface fields: `name` (string, required), `version` (string, required), `mcpServers` (optional), `contextFileName` (string or string[], optional), `excludeTools` (string[], optional).

Documentation also mentions: `description`, `settings` array, `themes` array.

`contextFileName` can be a string or array of strings. If omitted and `GEMINI.md` exists, that file is loaded. When an array, each entry is resolved independently.

**What validate.sh checks:** Cross-checks `name`, `version`, `description` against plugin.json/package.json. Validates `contextFileName` file(s) exist — handles both string and array forms. Validates `name` format (lowercase alphanumeric with dashes). Handles malformed JSON gracefully.

### Pi package.json

**Source:** `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md`
**Vendored:** `references/pi-readme.md`
**Last verified:** 2026-02-26

The `pi` key in package.json can contain: `extensions`, `skills`, `prompts`, `themes` — each a string or array of directory paths.

Without a `pi` manifest, pi auto-discovers from conventional directories (`extensions/`, `skills/`, `prompts/`, `themes/`).

Pi packages should include `"keywords": ["pi-package"]` for discovery.

**What validate.sh checks:** Extracts top-level `.pi` entry values via `jq`, verifies each resolves as a path. Warns if `keywords` does not include `"pi-package"`. Also checks for TypeScript syntax in `extensions/*.ts`.

## Known Drift

No known drift. All upstream spec requirements are covered.

## Previously Fixed Drift

- **Agent Skills spec alignment** (2026-02-26): Full implementation of agentskills.io specification — name format, description non-empty/length, compatibility length, frontmatter field allowlist, discovery paths, `user-invocable` portability warning.
- **Pi path filter tightened** (2026-02-26): Extracts `.pi` entry values instead of recursive string grepping to avoid false positives.
- **Malformed JSON handling** (2026-02-26): Crosscheck gracefully handles invalid JSON in plugin.json and gemini-extension.json.
- **plugin.json allowlist expanded** (2026-02-26): Added component path fields (`commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`).
- **contextFileName array handling** (2026-02-26): Both root and marketplace sub-plugin checks now handle `string | string[]`.
- **marketplace.json top-level validation** (2026-02-26): Added `name`, `owner.name`, `plugins` array, and relative `source` path resolution checks.
- **Gemini name format validation** (2026-02-26): Checks `name` is lowercase alphanumeric with dashes.
- **Pi keyword check** (2026-02-26): Warns if `keywords` does not include `"pi-package"`.

## Updating Specs

Vendored reference documents are in `references/`. To update:

1. Fetch from the source URL
2. Diff against the vendored copy
3. Update this SKILL.md's spec sections
4. Update validate.sh if the spec changed
5. Update "Last verified" dates
6. Add/remove items from "Known Drift"

## Adding a New Platform

When adding validation support for a new platform, complete every item:

### 1. Vendor the spec

- [ ] Identify the authoritative source(s): CLI validator > source code > docs
- [ ] Download the spec to `references/<platform>-<docname>.<ext>`
- [ ] Record the source URL, trust tier, and retrieval date

### 2. Add SKILL.md section

- [ ] Add a "### Platform Name" section under "Platform Specs" above
- [ ] Include: source URL, vendored path, last-verified date
- [ ] Document what validate.sh checks vs. what the spec requires
- [ ] Note any field allowlists, name constraints, or behavioral quirks

### 3. Add validation logic

- [ ] Add platform detection in validate.sh (file-presence based)
- [ ] Add a `--skip <platform>` value and document it in `usage()`
- [ ] Add `# Ref:` comments citing vendored reference file and line ranges
- [ ] Handle malformed input gracefully (error message, not crash)

### 4. Create test fixtures

- [ ] Create `tests/fixtures/<platform>-valid/` with a minimal passing case
- [ ] Create `tests/fixtures/<platform>-broken/` with at least one failing case
- [ ] Add `assert_pass` / `assert_fail` / `assert_fail_stderr` entries in `tests/run.sh`

### 5. Wire into freshness check

- [ ] Add fetch-and-diff entry in `.github/workflows/spec-freshness.yml`
- [ ] For open-source repos: add SHA pin env var (e.g., `NEW_PLATFORM_SHA`)
- [ ] For closed-source docs: hash-based comparison is automatic

### 6. Wire into CLI regression (if applicable)

- [ ] If the platform has a CLI validator, add a matrix entry in `.github/workflows/cli-regression.yml`
- [ ] Add pass/fail fixture cases for the CLI validator
- [ ] If no CLI validator exists, note this in the SKILL.md section

### 7. Update supporting files

- [ ] Add the new `--skip` value to `action.yml` documentation (if visible to consumers)
- [ ] Update `.github/copilot-instructions.md` review checklist
- [ ] Update cross-check logic if the platform shares metadata fields with others
