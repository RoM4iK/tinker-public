---
name: ticket-management
description: Use when creating or updating tickets. Covers ticket writing best practices, what to include, and what to avoid.
---

# Ticket Management

## TICKET CREATION AND UPDATE RULES

When creating or updating tickets (e.g., when planning backlog tickets):

Use `create_ticket` mcp tool when you will have full understanding of problem.

❌ **DO NOT** add "Files to Create" or "Files to Modify" sections
❌ **DO NOT** specify exact file paths in tickets
✅ **DO** describe the desired outcome and what needs to work
✅ **DO** provide context, constraints, and technical notes
✅ **DO** let workers discover which files need changes

**WHY:** File lists constrain worker thinking. When workers see "Files to modify: agents.rb", they may only touch that file and miss related changes needed elsewhere (e.g., MCP bridge files, permissions, etc.).

**Example - BAD:**
```markdown
## Files to Modify
- agents.rb

## Files to Create
- .claude/skills/memory/SKILL.md
```
Worker thinks: "Only edit these specific files."

**Example - GOOD:**
```markdown
## What You're Building
A memory skill that agents can use to store and retrieve knowledge. The skill should:
- Be discoverable by Claude Code runtime
- Expose search_memory and store_memory tools
- Be assigned to all agent types

## Technical Notes
Skills live in `.claude/skills/<name>/SKILL.md` and are assigned via `skills: []` array in agents.rb.
```
Worker thinks: "What files do I need to touch to accomplish this?" → Explores codebase → Finds all affected files.

## TICKET WRITING GUIDELINES

### Good Ticket Structure

1. **Title**: Clear, actionable description of the goal
2. **Context**: Why this work is needed, what problem it solves
3. **What You're Building**: Desired outcome and behavior
4. **Acceptance Criteria**: How to verify it works
5. **Technical Notes**: Architecture hints, patterns to follow, constraints
6. **Related Work**: Dependencies, related tickets, context links

### What to Include

- **Functional requirements** - What should the feature do?
- **Behavioral specifications** - How should it behave in edge cases?
- **Integration points** - What systems/components does this touch?
- **Testing guidance** - What scenarios should be tested?
- **Quality requirements** - Performance, security, accessibility needs
- **Reference implementations** - Similar patterns in the codebase

### What to Avoid

- Prescriptive file lists
- Step-by-step implementation instructions
- Overly detailed code snippets (unless showing a required pattern)
- Assumptions about which files will change
- Technical solutions when only requirements are known

