# AI Tooling Zone

Personal AI agent tools and integrations.

## Structure

| Directory | Purpose |
|-----------|---------|
| `claude-plugins/` | Claude Code plugins |
| `mcp-servers/` | MCP server implementations (future) |
| `tools/` | Standalone CLI tools (future) |

## Claude Skills Plugin (cuiv-skills)

**Install:** `/plugin install https://github.com/cuivienor/infra`

### Platform Support

- **Claude Code:** Native plugin install
- **Codex:** See `cuiv-skills/.codex/INSTALL.md`
- **OpenCode:** See `cuiv-skills/.opencode/INSTALL.md`

### Creating New Skills

1. Create `skills/<skill-name>/SKILL.md`
2. Add YAML frontmatter (name, description)
3. Write instructions in markdown
4. Bump version in `plugin.json`
5. Commit and push
