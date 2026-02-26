---
name: agent-skills-format
description: Use when creating, editing, or reviewing Agent Skills. Use when asked about skill structure, SKILL.md format, progressive disclosure, or skill distribution.
user-invocable: true
---

# Agent Skills Format

Open format for extending AI agent capabilities. Skills are folders with `SKILL.md` (YAML frontmatter + markdown) plus optional scripts, references, and assets.

## Quick Reference

| Component | Purpose |
|-----------|---------|
| `SKILL.md` | Required. YAML frontmatter + instructions |
| `scripts/` | Executable code (Python/Bash) |
| `references/` | Documentation loaded on demand |
| `assets/` | Templates, fonts, images for output |

### SKILL.md Template

```markdown
---
name: skill-name
description: What this does AND when to use it. Primary trigger mechanism.
---

# Skill Name

[Instructions]
```

## Progressive Disclosure

1. **Discovery** (~100 tokens): Only name + description at startup
2. **Activation**: Full SKILL.md when task matches
3. **Execution**: Scripts/references as needed

**Target**: Keep SKILL.md under 500 lines. Split to `references/` when approaching limit.

## Description Best Practices

Include WHAT and WHEN. This is how agents decide to activate.

```yaml
# Good
description: PDF toolkit for extracting text, creating PDFs, merging/splitting, forms. Use when processing PDF documents at scale.

# Bad
description: For PDF processing
```

## Design Principles

- Context window is shared resource
- Claude is smart; add non-obvious info only
- Prefer examples over verbose explanations
- Every paragraph must justify its token cost

### Degrees of Freedom

| Level | When | Format |
|-------|------|--------|
| High | Multiple approaches valid | Text |
| Medium | Preferred pattern with variation | Pseudocode |
| Low | Fragile ops, consistency critical | Scripts |

### External Tools & Executables

Skills have no formal dependency declaration. Path resolution is the agent's job. Choose the right pattern:

| Situation | Pattern |
|-----------|---------|
| Custom logic, fragile ops | Bundle in `scripts/`, reference via relative path from SKILL.md |
| Python CLI (pip-installable) | `uvx <tool>` or `uv run --directory <path> <tool>` |
| Node CLI (npm-installable) | `npx -y <package>` |
| MCP server in a plugin | `${CLAUDE_PLUGIN_ROOT}/server` or `npx` in `.mcp.json` |
| Standard system tool | Bare command on PATH, validate with `command -v` |

Document dependencies in `compatibility:` frontmatter. Scripts should validate tools at startup and print install hints on failure.

See [full-reference.md](references/full-reference.md) for path resolution patterns and examples.

## Anti-Patterns

- README.md, CHANGELOG.md in plugin root (not loaded into agent context; human-only docs)
- "When to use" in body (belongs in description)
- Deeply nested references
- Duplicate info across files
- Over-explaining known concepts
- Nesting skills under `skills/<plugin>/<skill>/` (won't be discovered)

## Claude Code Plugin Structure

Skills must be at `skills/<name>/SKILL.md`. Nested skills are NOT discovered.

```
skills/
├── main-skill/SKILL.md      # → plugin:main-skill ✓
├── feature/SKILL.md         # → plugin:feature ✓
└── main-skill/nested/       # → NOT discovered ✗
```

**Frontmatter name:** Use folder name only, not `plugin:name`. The prefix is added automatically.

## Platform Gotchas

- **Private repos require SSH URLs** (`git@github.com:...`), not HTTPS
- **Gemini:** `link` for local dev (immediate updates), `install` for remote
- **Claude:** Two-step—`marketplace add` registers source, then `plugin install`
- **Claude removal:** Uninstall plugin first, then remove marketplace (order matters)
- **Gemini invocation:** Natural language, not `@plugin skill` syntax

## Detailed Reference

See [full-reference.md](references/full-reference.md) for:
- Complete skill creation process
- Content organization patterns
- External tools and executable dependency patterns
- Output templates
- Integration approaches
- Validation and packaging
- Platform support matrix
