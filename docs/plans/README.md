# Planning Workflow

This directory contains planning documents organized by their lifecycle stage.

## Directory Structure

```
docs/plans/
├── ideas/      # Brainstorming and early concepts
├── active/     # Current/upcoming implementation plans
└── archive/    # Completed implementations (for reference)
```

## Workflow

### 1. Ideas → Brainstorming

**Location**: `ideas/`

Use this directory for:
- Early brainstorming and rough concepts
- "What if..." explorations
- Incomplete thoughts that need refinement
- Problems to solve (before you know the solution)

**Format**: Markdown files, can be informal and rough

**Example**: `ideas/improve-backup-retention.md`

---

### 2. Active Plans → Implementation

**Location**: `active/`

Move ideas here once they become concrete implementation plans.

Active plans should include:
- Clear problem statement
- Proposed solution approach
- Technical requirements
- Implementation steps (can be high-level)
- Success criteria

**Format**: Structured markdown with clear sections

**Example**: `active/storage-iac-plan.md`

**Working on a plan?** Keep it in `active/` while implementing. Update as you learn.

---

### 3. Archive → Completed

**Location**: `archive/`

Move plans here once implementation is complete.

Archived plans serve as:
- Historical reference ("how did we build this?")
- Decision documentation ("why did we choose this approach?")
- Templates for similar future work

**Keep**:
- The original plan (as-written, even if details changed)
- Add a "Completed" section at the top with:
  - Completion date
  - Link to related documentation
  - Notable deviations from plan
  - Lessons learned

**Example**: `archive/backup-implementation-summary.md`

---

## Tips

### When to Create a Plan

Create a plan when:
- The work involves multiple steps or components
- You need to think through architectural decisions
- The change affects multiple systems
- You might need to revisit the decision later
- You want to brainstorm before committing to an approach

**Don't overthink it**: A plan can be as simple as a bulleted list of steps.

### Keeping Plans Updated

- **During implementation**: Update active plans as you learn new information or change approach
- **After completion**: Add completion notes and move to archive
- **Don't worry about perfection**: Plans are working documents, not final reports

### Plan vs Documentation

**Plans** (this directory):
- Future-focused: "How should we build this?"
- Rough and iterative
- Can change as you learn

**Documentation** (`docs/guides/`, `docs/reference/`):
- Present-focused: "How does this work now?"
- Polished and stable
- Single source of truth

---

## Current Status

**Active Plans**:
```bash
ls -1 active/
```

**Archived Plans**:
```bash
ls -1 archive/
```

---

## Related Documentation

- [Repository Organization](../../README.md#planning-workflow)
- [IaC Strategy](../reference/homelab-iac-strategy.md)
- [Implementation Guides](../guides/)
