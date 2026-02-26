# Contributing

## Running tests

```sh
./tests/run.sh
```

Tests run `validate.sh` against fixture directories in `tests/fixtures/` and
assert pass/fail outcomes and stderr patterns. No external services needed —
tier 2 tool checks are skipped in tests via `--skip`.

## Adding a test

1. Create a fixture directory under `tests/fixtures/<name>/` with the minimal
   files needed to trigger the behavior.
2. Add an assertion in `tests/run.sh` using one of:
   - `assert_pass` — expects exit 0
   - `assert_fail` — expects nonzero exit
   - `assert_fail_stderr` — expects nonzero exit and a regex match in stderr
   - `assert_pass_stderr` — expects exit 0 and a regex match in stderr
3. Run `./tests/run.sh` and verify the new test passes.

Skip external tool checks with the `SKIP_EXTERNAL` variable already defined
in `run.sh`.

## Adding a fixture

Fixtures are self-contained directories. Each should contain only the files
needed for its test case. Common patterns:

- `skills/<name>/SKILL.md` — for SKILL.md validation tests
- `.claude-plugin/plugin.json` — for crosscheck tests
- `gemini-extension.json` — for Gemini validation tests
- `package.json` with `.pi` key — for Pi validation tests
- `scripts/validate-extra.sh` — for hook tests

If a fixture path is ignored by a global gitignore (e.g. `.claude/`), use
`git add -f` to force-add it.

## Updating vendored specs

Vendored specs live in `skills/spec-conformance/references/`. To update:

1. Fetch the latest from the source URL listed in
   `skills/spec-conformance/SKILL.md`.
2. Diff against the vendored copy.
3. Update `validate.sh` if the spec changed.
4. Update `skills/spec-conformance/SKILL.md` (spec sections, "Last verified"
   dates, "Known Drift").
5. Add or update tests for any new checks.

Sources:

| Spec | Source URL |
|------|-----------|
| Agent Skills | `https://raw.githubusercontent.com/agentskills/agentskills/main/docs/specification.mdx` |
| Claude plugin.json | `https://code.claude.com/docs/en/plugins-reference.md` |
| Claude marketplace.json | `https://code.claude.com/docs/en/plugin-marketplaces.md` |
| Gemini extension | `https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md` |
| Pi package | `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md` |

## Linting

Before committing, run:

```sh
shellcheck validate.sh tests/run.sh
```

CI also runs yamllint, jsonlint, and markdownlint on repo files.

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`,
`fix:`, `docs:`, `test:`, `chore:`.
