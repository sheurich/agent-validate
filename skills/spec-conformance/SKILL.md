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

### Claude Code plugin.json

**Source:** `https://code.claude.com/docs/en/plugins-reference.md`
**Vendored:** `references/claude-plugins-reference.md`
**Last verified:** 2026-02-26

Required fields: `name` only (manifest itself is optional).

Metadata fields (all optional): `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`.

Component path fields (all optional): `commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`. Each accepts `string|array` (some also accept `object` for inline config).

**What validate.sh checks:** Field allowlist covering all metadata and component path fields. Rejects any key not in the allowlist. Also runs `claude plugin validate` for structural checks (tier 2).

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

**What validate.sh checks:** Validates `owner.name` is present. Validates `plugins` is an array. Checks relative `source` paths resolve to directories. Cross-checks per-plugin `name`, `version`, `description` against sub-plugin manifests. Runs `claude plugin validate` on each non-strict-false sub-plugin.

### Gemini CLI gemini-extension.json

**Source:** `https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md`
**TypeScript interface:** `https://github.com/google-gemini/gemini-cli/blob/main/packages/a2a-server/src/config/extension.ts`
**Vendored:** `references/gemini-extension-reference.md`, `references/gemini-extension-config.ts`
**Last verified:** 2026-02-26

Interface fields: `name` (string, required), `version` (string, required), `mcpServers` (optional), `contextFileName` (string or string[], optional), `excludeTools` (string[], optional).

Documentation also mentions: `description`, `settings` array, `themes` array.

`contextFileName` can be a string or array of strings. If omitted and `GEMINI.md` exists, that file is loaded. When an array, each entry is resolved independently.

**What validate.sh checks:** Cross-checks `name`, `version`, `description` against plugin.json/package.json. Validates `contextFileName` file(s) exist — handles both string and array forms. Does not validate `name` format (lowercase, dashes).

### Pi package.json

**Source:** `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md`
**Vendored:** `references/pi-readme.md`
**Last verified:** 2026-02-26

The `pi` key in package.json can contain: `extensions`, `skills`, `prompts`, `themes` — each a string or array of directory paths.

Without a `pi` manifest, pi auto-discovers from conventional directories (`extensions/`, `skills/`, `prompts/`, `themes/`).

Pi packages should include `"keywords": ["pi-package"]` for discovery.

**What validate.sh checks:** Extracts all string values from `.pi` via `jq -r '.pi | .. | strings'`, filters for path-like values, verifies each resolves. Also checks for TypeScript syntax in `extensions/*.ts`. Does not validate `keywords` contains `pi-package`.

### SKILL.md Frontmatter

**Source:** Agent Skills Format specification (obra/agent-skills-format)
**Vendored:** `references/agent-skills-format.md`
**Last verified:** 2026-02-26

Required frontmatter fields: `name`, `description`.

Optional: `user-invocable` (boolean), `compatibility` (object).

The `name` should match the containing folder name. Exception: "promoted" skills where the grandparent directory is `skills`, `tools`, or `howto` may have a different name (warning, not error).

The `description` should include both WHAT the skill does and WHEN to use it.

Skills must be at `skills/<name>/SKILL.md` — nested skills are not discovered.

**What validate.sh checks:** Requires `name` and `description` in YAML frontmatter. Checks `name` matches folder name (warning for promoted skills). Checks for duplicate names across all skill directories. Does not validate `description` content quality.

## Known Drift

Tracked issues where validate.sh diverges from upstream specs:

1. **Pi keywords not checked** — Does not validate that `"keywords": ["pi-package"]` is present for Pi package discovery.

2. **Gemini name format not validated** — Does not check that extension `name` is lowercase with dashes matching the directory name.

3. **marketplace.json name field not required** — validate.sh checks for `owner.name` and `plugins` array, but does not require the top-level `name` field (which the spec lists as required).

## Previously Fixed Drift

These items were identified and fixed:

- **plugin.json allowlist expanded** (2026-02-26): Added component path fields (`commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`).
- **contextFileName array handling** (2026-02-26): Both root and marketplace sub-plugin checks now handle `string | string[]`.
- **marketplace.json top-level validation** (2026-02-26): Added `owner.name` required check, `plugins` array check, and relative `source` path resolution.

## Updating Specs

Vendored reference documents are in `references/`. To update:

1. Fetch from the source URL
2. Diff against the vendored copy
3. Update this SKILL.md's spec sections
4. Update validate.sh if the spec changed
5. Update "Last verified" dates
6. Add/remove items from "Known Drift"
