---
name: memory
description: Use for knowledge sharing across sessions. Search memory before starting work, store memory after learning. Critical for avoiding repeated mistakes and maintaining context.
---

# Agent Memory - Knowledge Sharing

## WHY Use Memory

Memory persists across ALL agent sessions. What you learn today helps other agents (and future you) tomorrow.

- Avoid repeating mistakes
- Reuse solutions that worked
- Maintain context across sessions
- Share knowledge between agents

## WHEN to Search Memory

### Before Starting Work
```bash
# Search for prior work on this ticket/topic
search_memory(query: "ticket #114", limit: 5)
search_memory(query: "daisyUI theme configuration", limit: 5)
```

### When Stuck or Blocked
```bash
# Search for similar problems or solutions
search_memory(query: "Stacked PRs phase dependency", limit: 5)
search_memory(query: "rails credentials error", limit: 5)
```

### Before Making Decisions
```bash
# Search for prior decisions on this topic
search_memory(query: "authentication", memory_type: "decision", limit: 5)
search_memory(query: "database schema", memory_type: "decision", limit: 5)
```

### When Encountering Errors
```bash
# Search for previous solutions to this error
search_memory(query: "ActiveRecord not found error", memory_type: "error", limit: 5)
```

## WHEN to Store Memory

### After Learning Something New
```bash
store_memory(
  content: "Learned that daisyUI themes are configured in application.tailwind.css with @plugin directive",
  memory_type: "fact",
  ticket_id: 89
)
```

### After Fixing a Bug
```bash
store_memory(
  content: "Fixed: Tailwind v4 requires @import 'tailwindcss' instead of @tailwind directives. Error: 'Unknown at rule @tailwind'",
  memory_type: "error",
  ticket_id: 89,
  metadata: { error_message: "Unknown at rule @tailwind", solution: "Use @import 'tailwindcss'" }
)
```

### After Making a Decision
```bash
store_memory(
  content: "Chose daisyUI winter theme as default over emerald because better color contrast for accessibility",
  memory_type: "decision",
  ticket_id: 89
)
```

### After Implementing a Pattern
```bash
store_memory(
  content: "When fixing existing PRs, always checkout the PR's branch using 'gh pr view X --json headRefName' instead of creating new branch",
  memory_type: "instruction",
  ticket_id: 98
)
```

### After Completing Work
```bash
store_memory(
  content: "Implemented daisyUI theme polish with 3 themes: winter (default), dracula (dark), corporate. All AVO cards converted to daisyUI components (card, badge, progress, alert). Theme switcher component created with Stimulus controller.",
  memory_type: "summary",
  ticket_id: 89
)
```

## Memory Types

| Type | When to Use | Example |
|------|-------------|---------|
| `decision` | After making an architectural choice | "Chose PostgreSQL over MySQL for JSON support" |
| `error` | After fixing a bug or error | "Fixed: 'undefined method' for nil - add .presence check" |
| `instruction` | For reusable patterns/workflows | "Always test on mobile before submitting PR" |
| `fact` | For learned information | "Ruby 3.4 requires syntax `it {}` instead of `lambda {}`" |
| `summary` | After completing significant work | "Phase 1 of epic #79: Added daisyUI and converted cards" |
| `context` | For project-specific info | "This project uses AVO admin framework with custom cards" |
| `code_snippet` | For useful code patterns | `store_memory(content: "Use `find_or_create_by` for upserts", memory_type: "code_snippet")` |

## Quick Reference

| Situation | Action |
|-----------|--------|
| Starting work on ticket | `search_memory(query: "ticket #X")` |
| Encountering error | `search_memory(query: "error message", memory_type: "error")` |
| Fixed an issue | `store_memory(content: "Fixed: ...", memory_type: "error")` |
| Made a choice | `store_memory(content: "Chose X because ...", memory_type: "decision")` |
| Learned new info | `store_memory(content: "Learned that ...", memory_type: "fact")` |
| Completed task | `store_memory(content: "Implemented ...", memory_type: "summary")` |

## Best Practices

### BE SPECIFIC
```bash
# Good
store_memory(content: "daisyUI 5.5.14 requires Tailwind CSS 4.1.18+ for @plugin syntax", memory_type: "fact")

# Too vague
store_memory(content: "Check daisyUI version compatibility", memory_type: "fact")
```

### INCLUDE CONTEXT
```bash
store_memory(
  content: "For AVO cards, use daisyUI 'card' component with 'bg-base-100' for theme-aware backgrounds",
  memory_type: "instruction",
  ticket_id: 89,
  metadata: { component: "avo_card", theme: "daisyui" }
)
```

### LINK TO TICKETS
```bash
store_memory(
  content: "git-workflow skill supports stacked PRs for phased development (Phase 1 → Phase 2 → Phase 3)",
  memory_type: "fact",
  ticket_id: 97
)
```

## Examples by Memory Type

### decision - Architectural Choices
```bash
# After choosing a library
store_memory(
  content: "Chose bun over npm/yarn because 10x faster install times and native ESM support",
  memory_type: "decision",
  ticket_id: 81
)

# After choosing an approach
store_memory(
  content: "Decided to use skills pattern (from ticket #98) instead of inline prompts for persistent workflows",
  memory_type: "decision",
  ticket_id: 114
)
```

### error - Bugs and Solutions
```bash
# After fixing a specific error
store_memory(
  content: "Fixed: 'ActionController::UnknownFormat' - Add 'format.js { render json: {...} }' to respond_to block",
  memory_type: "error",
  ticket_id: 105,
  metadata: { error_class: "ActionController::UnknownFormat", solution: "Add format.js response" }
)

# After resolving configuration issues
store_memory(
  content: "Fixed: daisyUI components not rendering - Needed to run 'bun run build:css' to compile Tailwind v4",
  memory_type: "error",
  ticket_id: 89
)
```

### instruction - Reusable Patterns
```bash
# Workflow guidance
store_memory(
  content: "When implementing epic subtasks, always check for auto-block dependencies via ticket.dependencies before starting work",
  memory_type: "instruction",
  ticket_id: 96
)

# Code pattern
store_memory(
  content: "Use 'find_by(id:)' instead of 'where(id:).first' to avoid loading entire relation",
  memory_type: "instruction",
  ticket_id: 100
)
```

### fact - Learned Information
```bash
# Technical fact
store_memory(
  content: "Tailwind CSS v4 uses @import instead of @tailwind directives. CSS config moved to @plugin block in CSS file itself",
  memory_type: "fact",
  ticket_id: 89
)

# Project-specific fact
store_memory(
  content: "This project uses Tinkered workflow: Workers implement → Reviewers audit → Orchestrators coordinate",
  memory_type: "fact",
  ticket_id: 98
)
```

### summary - Completed Work
```bash
# After completing a ticket
store_memory(
  content: "Ticket #89: Implemented daisyUI theme polish. 3 themes configured (winter, dracula, corporate). All AVO cards converted to daisyUI components. Created theme switcher controller and partial.",
  memory_type: "summary",
  ticket_id: 89
)

# After completing a phase
store_memory(
  content: "Epic #79 Phase 1 Complete: daisyUI installed, theme configured, base components converted. Ready for Phase 2: Advanced features.",
  memory_type: "summary",
  ticket_id: 79
)
```

## Search Patterns

### Search by Ticket
```bash
search_memory(query: "ticket #89", limit: 10)
search_memory(query: "#114", limit: 5)
```

### Search by Type
```bash
search_memory(memory_type: "decision", limit: 20)
search_memory(memory_type: "error", query: "daisyUI", limit: 10)
```

### Search by Keyword
```bash
search_memory(query: "authentication", limit: 10)
search_memory(query: "Stacked PRs", limit: 5)
search_memory(query: "AVO card", limit: 10)
```

### Search by Ticket Context
```bash
# Get all memories for current ticket
search_memory(ticket_id: 114, limit: 20)
```

## Workflow Integration

### Standard Work Pattern
```bash
# 1. Start: Search for context
search_memory(query: "ticket #114", limit: 5)
search_memory(query: "memory skill pattern", limit: 5)

# 2. Work: Implement solution
# ... code changes ...

# 3. Learn: Store discoveries
store_memory(content: "Memory skills use same directory structure as git-workflow", memory_type: "fact", ticket_id: 114)

# 4. Complete: Store summary
store_memory(content: "Created memory skill with search/store guidance, memory types, examples", memory_type: "summary", ticket_id: 114)
```

## Memory Quality Checklist

When storing memory, ensure:
- ✅ **Specific**: Contains actionable details
- ✅ **Typed**: Uses correct memory_type
- ✅ **Context**: Includes ticket_id or metadata
- ✅ **Searchable**: Uses keywords others might search for
- ✅ **Unique**: Doesn't duplicate existing memories

When searching memory:
- ✅ **Before starting**: Check for prior work
- ✅ **When stuck**: Look for similar solutions
- ✅ **Before deciding**: Check prior decisions
- ✅ **Use filters**: Apply memory_type, ticket_id when relevant
