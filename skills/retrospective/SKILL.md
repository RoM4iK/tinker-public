---
name: retrospective
description: Generate comprehensive learning documents by combining information from tickets, memories, GitHub PRs, and proposals. Use after completing significant work to capture lessons learned.
---

# Retrospective - Organizational Learning

## WHY Use Retrospective

Retrospectives transform scattered work artifacts into structured learning documents that help the entire team avoid repeating mistakes and reuse successful patterns.

- **Capture lessons learned** - Explicitly document what went wrong and how to fix it
- **Share successful patterns** - Make solutions discoverable for future agents
- **Build institutional knowledge** - Create a permanent record of decisions and their outcomes
- **Prevent recurring issues** - Make past errors and their solutions easily searchable

## WHEN to Use Retrospective

### After Completing Significant Work
```bash
# After finishing a complex ticket
retrospective(ticket_id: 128)

# After fixing a particularly difficult bug
retrospective(ticket_id: 157)

# After implementing a major feature
retrospective(ticket_id: 89)
```

### During Research/Analysis
```bash
# When analyzing patterns across multiple tickets
# Use retrospective to understand what actually happened
retrospective(ticket_id: 128)
```

### Before Starting Related Work
```bash
# Search for past retrospectives on similar topics
search_memory(query: "retrospective authentication", limit: 5)

# Read a past retrospective to avoid repeating mistakes
# Then generate a new one for current work
```

## HOW Retrospective Works

The retrospective skill gathers information from multiple sources:

1. **Ticket Details** - `get_ticket(ticket_id)` for title, description, working_memory, status, PR URL
2. **Related Memories** - `search_memory(query: "ticket #X")` for implementation details, errors, decisions
3. **Comments** - `list_comments(ticket_id)` for review feedback, questions, decisions
4. **GitHub PR** - Fetch PR details and review comments via `gh` CLI or GitHub API
5. **Related Proposals** - Search for proposals linked to this ticket

## Retrospective Structure

```markdown
# Retrospective: [Ticket Title]

## Overview
1-2 sentence summary of what the ticket accomplished.

## What We Built
- Implementation details from working_memory
- Key changes made
- Features added

## What Went Wrong
- Errors encountered (from error memories)
- Review feedback (from code_review comments)
- Issues discovered during implementation

## How We Fixed It
- Solutions applied (from error memories)
- Follow-up tickets created
- Pattern changes made

## Links
- Ticket: [link]
- PR: [link]
- Related Tickets: [list]
- Related Memories: [list]

## Lessons Learned
- Decisions made and why
- Patterns to follow/avoid
- Checklist items for future work
```

## Generating a Retrospective

### Step-by-Step Process

```bash
# 1. Get ticket details
get_ticket(ticket_id: 128)

# 2. Search for related memories
search_memory(query: "ticket #128", limit: 20)

# 3. Get comments (includes review feedback)
list_comments(ticket_id: 128)

# 4. Fetch PR details if pull_request_url exists
gh pr view 64 --json title,body,state,comments,reviews

# 5. Synthesize into structured markdown
# (Use the template below)

# 6. Store as memory for future reference
store_memory(
  content: "# Retrospective: Ticket #128\n\n...",
  memory_type: "summary",
  ticket_id: 128,
  metadata: { retrospective: true }
)
```

## Template: Retrospective Document

```markdown
# Retrospective: [Ticket Title] (#[ticket_id])

**Status:** [done/cancelled/etc]
**Completed:** [date]
**PR:** [link if exists]

---

## Overview

[1-2 sentences summarizing what was accomplished]

---

## What We Built

[Extract from ticket.working_memory.implementation_summary or synthesize from memories]

- [Feature 1]
- [Feature 2]
- [Key implementation detail]

**Files Changed:**
- [List key files modified/created]

---

## What Went Wrong

[Extract from error memories and code_review comments with comment_type: "code_review"]

### Issue 1: [Title]
- **What happened:** [Description from error memory or review comment]
- **Impact:** [How it blocked/broke things]
- **Discovered by:** [review comment or during implementation]

### Issue 2: [Title]
- **What happened:** ...
- **Impact:** ...
- **Discovered by:** ...

---

## How We Fixed It

[Extract from error memories (solutions) and follow-up tickets]

### Fix 1: [Issue Title]
- **Solution:** [What was changed]
- **Implementation:** [Code changes made]
- **Follow-up:** [Any tickets created to address]

### Fix 2: [Issue Title]
- **Solution:** ...
- **Implementation:** ...
- **Follow-up:** ...

---

## Links

- **Ticket:** [app URL or ticket number]
- **PR:** [GitHub URL if exists]
- **Related Tickets:** [ticket numbers found in dependencies, comments, or memories]
- **Related Memories:** [memory IDs found via search_memory]

---

## Lessons Learned

[Extract decisions, patterns, and checklists from all sources]

### Decisions Made
- **[Decision]:** [Why it was made, what alternatives were considered]
- **[Decision]:** ...

### Patterns to Follow
- **[Pattern name]:** [Description and when to use]
  ```ruby
  # Code example if applicable
  ```

### Anti-Patterns to Avoid
- **[Anti-pattern]:** [What NOT to do and why]
- **[Anti-pattern]:** ...

### Checklist for Future Work
When working on similar features:
- [ ] [Checklist item 1]
- [ ] [Checklist item 2]
- [ ] [Checklist item 3]

### Related Work
- This relates to ticket #[number] (similar feature/pattern)
- See memory #[id] for related information
```

## Example: Ticket #128 (Archival System)

Below is an example retrospective generated for ticket #128.

```markdown
# Retrospective: Ticket #128 - Implement ticket archival system with cascade and auto-archive

**Status:** done
**Completed:** 2025-12-28
**PR:** https://github.com/RoM4iK/tinker/pull/64

---

## Overview

Implemented a complete ticket archival system to hide completed work from main views while preserving historical data. Includes cascade logic for epic/subtask relationships and auto-archive for cancelled tickets.

---

## What We Built

**Database Schema:**
- Added `archived` (boolean, indexed) and `archived_at` (timestamp) columns to tickets table

**Model Changes (`app/models/ticket.rb`):**
- `archive!` method - only works for done/cancelled tickets, raises error otherwise
- `unarchive!` method - with optional `unarchive_subtasks` parameter
- `auto_archive_if_cancelled` callback - automatically archives cancelled tickets
- Cascade logic: archiving epic archives all subtasks; archiving all subtasks archives parent epic
- `active` scope - excludes archived tickets
- `archived` scope - only archived tickets

**MCP Tools (`app/controllers/api/v1/mcp_controller.rb`):**
- `archive_ticket` - archive a single ticket
- `archive_tickets` - archive multiple tickets at once
- `list_archived_tickets` - list only archived tickets
- `unarchive_ticket` - unarchive a ticket (with unarchive_subtasks option)
- Updated `handle_list_tickets` to add `include_archived` filter (default: false)

**API Changes:**
- Updated `/api/v1/tickets` index to support `include_archived` filter
- Updated TicketSerializer to expose `archived` and `archived_at`

**Query Updates:**
- ProjectSerializer: `open_ticket_count` and `ticket_count` exclude archived
- DashboardController: `kanban` action excludes archived by default, supports `show_archived` param
- McpController: `handle_get_status` excludes archived tickets

**UI Changes:**
- Kanban board: removed `cancelled` status from display
- Kanban board: added "Show Archived" toggle
- Avo admin: added `archived` and `archived_at` fields to Ticket resource
- Avo admin: added ArchiveTicket and UnarchiveTicket actions
- JavaScript: added `toggleArchived` action to kanban-filter controller

**Tests (`spec/models/ticket_spec.rb`):**
- Tests for archive! validation (done/cancelled only)
- Tests for cascade logic (epic → subtasks, all subtasks → epic)
- Tests for unarchive! with/without subtasks option
- Test for auto-archive callback
- Tests for active and archived scopes

---

## What Went Wrong

### Issue 1: MCP Tools Missing from Permissions (CRITICAL)
- **What happened:** The 4 new MCP tools (archive_ticket, archive_tickets, list_archived_tickets, unarchive_ticket) were added to `mcp_controller.rb` but NOT added to `config/tinker/mcp_permissions.yml`
- **Impact:** Agents could not use these tools - they were blocked by the permission system
- **Discovered by:** Code review (first review comment)
- **Recurrence:** This same issue occurred in tickets #92 and #95

### Issue 2: Initial Submission Without Implementation
- **What happened:** Ticket was submitted for audit with no actual code written - only a working_memory summary
- **Impact:** Wasted reviewer time, ticket had to be sent back
- **Discovered by:** Code review (comment #106)

### Issue 3: Reset Filters Bug
- **What happened:** `kanban_filter_controller.js#resetFilters()` didn't reset the `showArchived` toggle
- **Impact:** UI inconsistency when resetting filters
- **Discovered by:** Code review

---

## How We Fixed It

### Fix 1: Added MCP Permissions
- **Solution:** Added all 4 archive tools to `config/tinker/mcp_permissions.yml` for reviewer and planner roles
- **Implementation:** Direct YAML edit to permissions file
- **Follow-up:** None - fixed in same PR

### Fix 2: Implemented Complete Feature
- **Solution:** Full implementation of all acceptance criteria before re-submitting
- **Implementation:** Created migration, model methods, MCP tools, API changes, UI updates, and tests
- **Follow-up:** None

### Fix 3: Fixed Reset Filters
- **Solution:** Added `showArchived.checked = false` to `resetFilters()` method
- **Implementation:** JavaScript edit to kanban_filter_controller.js
- **Follow-up:** None

---

## Links

- **Ticket:** #128
- **PR:** https://github.com/RoM4iK/tinker/pull/64
- **Related Tickets:** #146 (MCP archive tools registration follow-up)
- **Related Memories:**
  - Memory #50: Full implementation summary
  - Memory #51: MCP permissions pattern lesson
  - Memory #52: Review notes about missing permissions

---

## Lessons Learned

### Decisions Made
- **Cascade logic direction:** Archiving an epic always archives subtasks (one-way). Unarchiving is optional (`unarchive_subtasks: false` by default) to avoid cluttering views when parent is unarchived.
- **Infinite recursion prevention:** Mark ticket as archived FIRST, then cascade to children. Use `update_columns` for parent updates to avoid callbacks.

### Patterns to Follow
- **MCP Tool Addition Pattern:** When adding new MCP tools, always update BOTH:
  1. `app/controllers/api/v1/mcp_controller.rb` - Add to MCP_TOOLS and create handler
  2. `config/tinker/mcp_permissions.yml` - Add to appropriate agent roles
- **Auto-archive via callback:** Use `update_column` in callbacks to avoid triggering additional callbacks
- **Cascade with update_columns:** Use `update_columns` (plural) to skip validations and callbacks when updating parent during cascade

### Anti-Patterns to Avoid
- **NEVER submit without implementation:** Working memory summaries are not code. All acceptance criteria must be implemented before audit.
- **NEVER forget MCP permissions:** This is a recurring pattern. Check permissions file whenever reviewing MCP tool additions.

### Checklist for Future MCP Tool Additions
When adding new MCP tools:
- [ ] Add tool definition to `MCP_TOOLS` constant in mcp_controller.rb
- [ ] Create handler method `handle_<tool_name>` in mcp_controller.rb
- [ ] Add tool to `config/tinker/mcp_permissions.yml` for appropriate roles
- [ ] Add integration tests to spec/requests/api/v1/mcp_spec.rb
- [ ] Verify tools appear in GET /api/v1/mcp/tools response

### Related Work
- Ticket #146: MCP archive tools registration - cleaned up duplicate archive_ticket tool
- Memory #51: Documents the MCP permissions pattern
- Tickets #92, #95: Previous occurrences of missing MCP permissions issue
```

## Storing Retrospectives

After generating a retrospective, store it as a memory for future reference:

```bash
store_memory(
  content: "# Retrospective: Ticket #128 - Implement ticket archival system\n\n...",
  memory_type: "summary",
  ticket_id: 128,
  metadata: {
    retrospective: true,
    generated_at: Time.current.iso8601
  }
)
```

## Searching Past Retrospectives

```bash
# Find retrospectives for a specific ticket
search_memory(query: "retrospective ticket #128", limit: 5)

# Find all retrospectives
search_memory(memory_type: "summary", query: "retrospective", limit: 20)

# Find retrospectives on a topic
search_memory(query: "retrospective authentication", limit: 5)
```

## Quick Reference

| Task | MCP Tool / Action |
|------|-------------------|
| Get ticket details | `get_ticket(ticket_id)` |
| Find related memories | `search_memory(query: "ticket #X", limit: 20)` |
| Get review feedback | `list_comments(ticket_id)` |
| Get PR details | `gh pr view <number> --json title,body,comments,reviews` |
| Store retrospective | `store_memory(content, memory_type: "summary", ticket_id)` |
| Find past retrospectives | `search_memory(query: "retrospective", limit: 20)` |

## Retrospective Quality Checklist

When generating a retrospective:
- ✅ **Overview** is concise (1-2 sentences)
- ✅ **What We Built** includes key files and features
- ✅ **What Went Wrong** extracts from error memories and review comments
- ✅ **How We Fixed It** documents solutions and follow-ups
- ✅ **Links** section connects all related artifacts
- ✅ **Lessons Learned** extracts decisions, patterns, and checklists
- ✅ **Stored as memory** for future reference
