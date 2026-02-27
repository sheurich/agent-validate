# Security Policy

## Reporting a Vulnerability

Report security issues by emailing the maintainer directly. Do not open a
public issue.

Include:

- Description of the vulnerability
- Steps to reproduce
- Affected versions

Expect an initial response within 72 hours. We will coordinate disclosure
timing with you.

## Trust Model

agent-validate runs linters and validation tools against a target directory.
Two mechanisms execute code from that directory:

1. **`scripts/validate-extra.sh`** — If present in the target repo, this hook
   runs via `bash` with full shell access. It inherits the caller's
   environment.

2. **npm packages via `npx`** — Tier 2 checks (`claude plugin validate`,
   `gemini extensions validate`) download and execute npm packages. Versions
   are pinned but the packages themselves run arbitrary code.

Treat `validate.sh` the same as any CI script: do not run it against
untrusted repositories without reviewing their contents first.

## Supply Chain

- All npm packages are invoked via `npx --yes` with pinned versions.
- GitHub Actions in CI workflows use full SHA pins.
- Tool version defaults are overridable via environment variables.

See the "Supply chain" section in README.md for details.
