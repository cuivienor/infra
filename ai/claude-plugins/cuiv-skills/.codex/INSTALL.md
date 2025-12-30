# Installing Cuiv-skills for Codex

Quick setup to enable cuiv-skills in Codex.

## Installation

1. **Clone the infra repository**:
   ```bash
   mkdir -p ~/.codex
   git clone https://github.com/cuivienor/infra.git ~/.codex/infra
   ```

2. **Create symlink to plugin** (for easier paths):
   ```bash
   ln -sf ~/.codex/infra/ai/claude-plugins/cuiv-skills ~/.codex/cuiv-skills
   ```

3. **Create personal skills directory**:
   ```bash
   mkdir -p ~/.codex/skills
   ```

4. **Update ~/.codex/AGENTS.md** to include this section:
   ```markdown
   ## Cuiv-skills System

   <EXTREMELY_IMPORTANT>
   You have cuiv-skills. Cuiv-skills teach you new skills and capabilities. RIGHT NOW run: `~/.codex/cuiv-skills/.codex/cuiv-skills-codex bootstrap` and follow the instructions it returns.
   </EXTREMELY_IMPORTANT>
   ```

## Verification

Test the installation:
```bash
~/.codex/cuiv-skills/.codex/cuiv-skills-codex bootstrap
```

You should see skill listings and bootstrap instructions.

## Updating

```bash
cd ~/.codex/infra && git pull
```

## Alternative: Direct Path (No Symlink)

If you prefer not to use a symlink, use the full path everywhere:
```bash
~/.codex/infra/ai/claude-plugins/cuiv-skills/.codex/cuiv-skills-codex bootstrap
```

And update AGENTS.md accordingly.
