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
**Last verified:** 2026-03-05

This is the canonical source of truth for SKILL.md validation. The Agent Skills open standard defines:

Required frontmatter: `name`, `description`.

Optional frontmatter: `license`, `compatibility`, `metadata`, `allowed-tools`.

**Field allowlist:** Only `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility` are permitted. The reference validator (`skills-ref validate`) rejects any other fields.

**Name constraints:** 1–64 chars, lowercase alphanumeric + hyphens, no leading/trailing hyphens, no consecutive hyphens, must match parent directory name.

**Description constraints:** Non-empty string, max 1024 chars.

**Compatibility constraints:** Max 500 chars if present.

**What validate.sh checks:** All of the above, plus:
- `user-invocable` accepted with a portability warning (used by Claude Code for slash menu visibility; not in the spec)
- `argument-hint` accepted with a portability warning (used by Pi for CLI hint display; not in the spec)
- `disable-model-invocation` accepted with a portability warning (used by Pi to hide skills from system prompt; not in the spec)
- Name-folder mismatch configurable: error by default, skippable via `--skip skill-name-match`
- Promoted skills (grandparent is `skills`, `tools`, or `howto`) get warnings instead of errors for name mismatch
- Scans: `skills/`, `.agents/skills/`, `.claude/skills/`, `.opencode/skills/`, `plugins/*/skills/`
- Duplicate name detection across all discovered skills

### Claude Code plugin.json

**Source:** `https://code.claude.com/docs/en/plugins-reference.md`
**Vendored:** `references/claude-plugins-reference.md`
**Last verified:** 2026-03-05

Required fields: `name` only (manifest itself is optional).

Metadata fields (all optional): `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`.

Component path fields (all optional): `commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`. Each accepts `string|array` (some also accept `object` for inline config).

**What validate.sh checks:** Field allowlist covering all metadata and component path fields. Rejects any key not in the allowlist. Also runs `claude plugin validate` for structural checks (tier 2). Handles malformed JSON gracefully (error, not crash).

### Claude Code marketplace.json

**Source:** `https://code.claude.com/docs/en/plugin-marketplaces.md`
**Vendored:** `references/claude-plugin-marketplaces.md`
**Last verified:** 2026-03-05

Required top-level fields: `name`, `owner` (with required `owner.name`), `plugins` array.

Optional top-level: `metadata.description`, `metadata.version`, `metadata.pluginRoot`.

Per-plugin required: `name`, `source`.

Per-plugin optional: `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`, `category`, `tags`, `strict`, `commands`, `agents`, `hooks`, `mcpServers`, `lspServers`.

`strict` (boolean, default true): when false, plugin.json is not the authority for component definitions.

Source types: relative paths, GitHub repos (`github:owner/repo`), git URLs, npm packages. Only relative paths are validated for resolution.

**What validate.sh checks:** Validates `name`, `owner.name`, and `plugins` array are present. Rejects `source` paths containing `..`. Checks relative `source` paths resolve to directories. Cross-checks per-plugin `name`, `version`, `description` against sub-plugin manifests. Runs `claude plugin validate` on each non-strict-false sub-plugin.

### Gemini CLI gemini-extension.json

**Source:** `https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md`
**TypeScript interface:** `https://github.com/google-gemini/gemini-cli/blob/main/packages/cli/src/config/extension.ts`
**Vendored:** `references/gemini-extension-reference.md`, `references/gemini-extension-config.ts`
**Last verified:** 2026-03-05

Interface fields: `name` (string, required), `version` (string, required), `mcpServers` (optional), `contextFileName` (string or string[], optional), `excludeTools` (string[], optional), `settings` (ExtensionSetting[], optional), `themes` (CustomTheme[], optional), `plan` (object with optional `directory`, optional — **see drift note below**).

Documentation also mentions: `description`, policy engine (`.toml` files in `policies/` directory).

**`description` gap:** The `description` field appears in the reference docs but is NOT in the `ExtensionConfig` TypeScript interface. validate.sh includes it in the allowlist based on the docs.

**`plan` field drift:** The `plan` field is present in the `main`-branch TypeScript interface (`gemini-extension-config.ts`) but is **not yet shipped** in the 0.31.0 stable release. The field is kept in the allowlist to avoid false errors for extensions targeting HEAD. If a future stable release adds it, remove this note.

**Sub-components (0.31.0):** Gemini CLI 0.31.0 supports extension sub-components: `commands/*.toml` (command definitions), `hooks/hooks.json` (lifecycle hooks), `agents/*.md` (agent definitions), `policies/*.toml` (policy rules). validate.sh checks JSON/TOML syntax and agent frontmatter when these directories exist. TOML checks require `taplo` on PATH.

**`gemini skills` CLI:** Gemini 0.31.0 introduces first-class `gemini skills list` / `gemini skills install` commands for standalone skill management. validate.sh checks installed skills via `gemini skills list` in Tier 3 deployment verification.

`contextFileName` can be a string or array of strings. If omitted and `GEMINI.md` exists, that file is loaded. When an array, each entry is resolved independently.

**What validate.sh checks:** Cross-checks `name`, `version`, `description` against plugin.json/package.json. Validates `contextFileName` file(s) exist — handles both string and array forms. Validates `name` format (lowercase alphanumeric with dashes). **Field allowlist** covering all `ExtensionConfig` interface fields: `name`, `version`, `description`, `mcpServers`, `contextFileName`, `excludeTools`, `settings`, `themes`, `plan` — rejects any key not in the allowlist. Handles malformed JSON gracefully. Validates sub-component syntax: `hooks/hooks.json` (JSON), `commands/*.toml` and `policies/*.toml` (TOML via taplo), `agents/*.md` (YAML frontmatter). Tier 3 deployment verifies installed skills via `gemini skills list`.

### Pi package.json

**Source:** `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md`
**Vendored:** `references/pi-readme.md`
**Last verified:** 2026-03-05

The `pi` key in package.json can contain: `extensions`, `skills`, `prompts`, `themes` — each a string or array of directory paths. It can also contain `video` and `image` — URL strings for the [package gallery](https://shittycodingagent.ai/packages) preview (not file paths).

Without a `pi` manifest, pi auto-discovers from conventional directories (`extensions/`, `skills/`, `prompts/`, `themes/`).

Pi packages should include `"keywords": ["pi-package"]` for discovery.

**What validate.sh checks:** Extracts top-level `.pi` entry values via `jq`, skips URL values (`https?://`), verifies remaining values resolve as paths. Warns if `keywords` does not include `"pi-package"`. Also checks for TypeScript syntax in `extensions/*.ts`.

### Pi Skills

**Source:** `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md`
**Vendored:** `references/pi-skills.md`
**Last verified:** 2026-03-05

Pi 0.56.0 documents skill frontmatter in `docs/skills.md`. In addition to the Agent Skills specification fields, Pi recognizes:

- `disable-model-invocation` (boolean): when `true`, the skill is hidden from the system prompt; users must invoke it explicitly via `/skill:name`.

Pi ignores unknown frontmatter fields (they don't cause errors in Pi itself). validate.sh treats `disable-model-invocation` as a known extension and emits a portability warning rather than an error.

### Codex (AGENTS.md / codex.md)

**Source:** No formal specification. Codex uses `AGENTS.md` (shared with OpenCode) and `codex.md` for agent instructions.

**What validate.sh checks:** Detects presence of `AGENTS.md` and/or `codex.md`. Runs markdownlint on detected files (unless `markdown` is skipped). No structural validation beyond markdown lint — no known schema or field requirements exist yet.

**What validate.sh doesn't check:** File content structure, frontmatter, or any Codex-specific conventions. If Codex publishes a spec in the future, add structural checks here.

### OpenCode (AGENTS.md)

**Source:** No formal specification. OpenCode uses `AGENTS.md` for agent instructions.

**What validate.sh checks:** Detects presence of `AGENTS.md`. Runs markdownlint on the file (unless `markdown` is skipped). No structural validation beyond markdown lint.

**What validate.sh doesn't check:** File content structure or any OpenCode-specific conventions. If OpenCode publishes a spec in the future, add structural checks here.

## Tier 3: Deployment Verification

Deployment checks are **opt-in** via `--check-deploy`. They verify installed
state on the host, not repo structure. Off by default — CI runners typically
lack agent CLIs in the right state.

### Claude Code

Requires `claude` binary on PATH. Parses `claude plugin list --json` and
`claude plugin marketplace list --json`. Checks:
- Each marketplace.json name appears in registered marketplaces
- Each plugin (root + marketplace sub-plugins) is installed and enabled
- Plugin matching uses `.id` prefix (`name@marketplace` format)

### Gemini CLI

Requires `gemini` binary on PATH. Parses `gemini extensions list -o json`.
Checks:
- Extension name from gemini-extension.json appears in installed list
- `.isActive` is true (not just installed)
- Repo skills are registered via `gemini skills list` (first-class skill management in 0.31.0)

### Shared skills hub (~/.agents/skills/)

No CLI needed — checks directory presence. Checks:
- Each SKILL.md name from the repo has a matching directory under
  `~/.agents/skills/` (or `$AGENTS_SKILLS_DIR` if set)

### What deployment checks don't do

- No machine-type awareness (work/personal) — consumer-repo concern
- No content validation (do skills actually work) — domain-specific
- No installation commands — checks state, doesn't modify it

## Known Drift

- **Gemini `plan` field (main vs. stable):** The `plan` field exists in the `main`-branch `ExtensionConfig` TypeScript interface but is not present in Gemini CLI 0.31.0 stable. The allowlist includes `plan` to avoid false errors; extensions targeting `main` will validate correctly. Remove this entry when `plan` ships in a stable release.
- **Gemini `description` gap:** The `description` field appears in the extension reference docs but is not in the `ExtensionConfig` TypeScript interface. The allowlist includes it based on the documentation.

## Previously Fixed Drift

- **Pi URL false positives** (2026-03-05): `video` and `image` fields in `.pi` are URL strings for the package gallery, not file paths. The jq extraction now skips `https?://` values.
- **`disable-model-invocation` misclassified** (2026-03-05): Pi 0.56.0 documents this SKILL.md frontmatter field in `docs/skills.md`. Previously rejected as an unknown field; now accepted with a portability warning.
- **Gemini sub-component validation** (2026-03-05): Added syntax checks for `hooks/hooks.json`, `commands/*.toml`, `policies/*.toml`, and `agents/*.md` frontmatter.
- **Gemini extension field allowlist** (2026-03-05): Rejects unknown fields in `gemini-extension.json` against `ExtensionConfig` interface. Added `plan` drift documentation.
- **Codex/OpenCode markdown lint** (2026-03-04): Detected `AGENTS.md`/`codex.md` files are now markdownlinted.

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
