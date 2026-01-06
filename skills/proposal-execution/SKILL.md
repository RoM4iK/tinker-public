---
name: proposal-execution
description: Use when executing approved proposals. Researchers can execute ANY approved proposal (not just their own) to perform actions like memory cleanup, marking proposals ready for ticket/skill creation.
---

# Proposal Execution

## Overview

Researchers can create proposals, but they cannot execute them directly - they need approval first. Once a proposal is **approved** by a human/reviewer, **any** researcher can use `execute_proposal` to carry out the proposed action.

## When to Use

Use `execute_proposal` when:
- Your proposal has been **approved** (status = "approved")
- You want to perform the action described in the proposal

## Important: Workflow Separation

### Immediate-Execution Proposals (Use execute_proposal)
- `memory_cleanup`: Deletes memories immediately when executed
- `test_gap`: Creates a ticket automatically when executed

These use `execute_proposal` because the service performs the action immediately.

### Research-Required Proposals (Use create_ticket_from_proposal directly)
- `task`: Requires research before ticket creation
- `autonomous_task`: Requires research before ticket creation (reviewer-approved)
- `skill_proposal`: Requires research before skill file creation
- `refactor`: Requires research before ticket creation

**DO NOT use `execute_proposal` for these types.** Instead:
1. Wait for proposal approval (human or reviewer)
2. Do your research (investigate codebase, understand requirements)
3. Use `create_ticket_from_proposal` to create the ticket directly

The `create_ticket_from_proposal` function will:
- Accept proposals with status "approved"
- Mark the proposal as "executed" when the ticket is created
- Handle the status transition automatically

**Key differences:**
- `autonomous_task` and `test_gap` can be approved by reviewer (not requiring human approval)
- Tickets from autonomous workflow proposals start in **backlog** status (skip draft)
- Tickets from human workflow proposals start in **draft** status

## Execution Workflow by Proposal Type

### memory_cleanup
Deletes agent memories specified in `metadata.memory_ids_to_delete`.

**Execution result:**
```json
{
  "action": "deleted_memories",
  "count": 3,
  "memory_ids": [1, 2, 3]
}
```

**Example:**
```bash
execute_proposal(proposal_id: 42)
# Deletes memories [10, 15, 20] per proposal #42
```

### task
**DO NOT use `execute_proposal` for task proposals.**

After approval (human), use `create_ticket_from_proposal` directly:
1. Wait for proposal approval (by human)
2. Do your research (investigate codebase, understand requirements)
3. Use `create_ticket_from_proposal` to create the ticket
4. The proposal will be marked as executed when the ticket is created

**Note:** Task proposals require human approval and tickets start in **draft** status.

### task (withdrawal)
If the proposal has `metadata.target_proposal_id`, it withdraws the target proposal instead of creating a ticket.

**Execution result:**
```json
{
  "action": "withdrew_proposal",
  "target_proposal_id": 41,
  "target_title": "Obsolete proposal"
}
```

### autonomous_task
**DO NOT use `execute_proposal` for autonomous_task proposals.**

After approval (by reviewer), use `create_ticket_from_proposal` directly:
1. Wait for proposal approval (by reviewer)
2. Do your research (investigate codebase, understand requirements)
3. Use `create_ticket_from_proposal` to create the ticket
4. Ticket will be created in **backlog** status (not draft)
5. The proposal will be marked as executed when the ticket is created

**Note:** Autonomous_task proposals can be approved by reviewer (not requiring human approval).

### refactor
**Special case: refactor proposals DO use `execute_proposal` and auto-create tickets.**

The backend handles refactor proposals differently - when you execute a refactor proposal, it automatically creates the ticket with evidence links.

**Execution result:**
```json
{
  "action": "created_ticket",
  "ticket_id": 124,
  "ticket_title": "Refactor: Improve database query performance"
}
```

**Workflow:**
1. Wait for proposal approval (by human)
2. Use `execute_proposal` - ticket is created automatically with evidence links
3. No need for `create_ticket_from_proposal`

**Note:** Refactor is the only ticket-creation type that still uses `execute_proposal` (for backward compatibility).

### test_gap
Creates a ticket for adding tests automatically. Starts in **backlog** status (autonomous workflow).

**Execution result:**
```json
{
  "action": "created_ticket",
  "ticket_id": 125,
  "ticket_title": "Add tests: Payment processing edge cases"
}
```

### skill_proposal
**DO NOT use `execute_proposal` for skill_proposal proposals.**

After approval (human), use `create_ticket_from_proposal` directly:
1. Wait for proposal approval (by human)
2. Do your research (understand requirements, check existing skills)
3. Use `create_ticket_from_proposal` to create a ticket for the skill file
4. Create the skill file manually (.claude/skills/my-skill/SKILL.md)
5. The proposal will be marked as executed when the ticket is created

**Note:** Skill proposals require human approval. The ticket tracks the skill file creation work.

## Example Workflows

### Memory Cleanup (Immediate Execution)
```ruby
# 1. Create a memory cleanup proposal
create_proposal(
  title: "Clean up obsolete test memories",
  proposal_type: "memory_cleanup",
  reasoning: "These memories are from old test runs and are no longer relevant",
  confidence: 75,
  priority: "low",
  metadata: {
    memory_ids_to_delete: [100, 101, 102],
    evidence_links: [
      { type: "memory", id: 100, description: "Outdated test configuration" }
    ]
  }
)

# 2. Check if approved
my_proposals = list_proposals(status: "approved")

# 2. Execute the approved proposal
execute_proposal(proposal_id: 42)
# => Deletes memories 100, 101, 102
# => Marks proposal #42 as "executed"
```

### Task (Direct to create_ticket_from_proposal)
```ruby
# 1. Wait for proposal approval (by human)
# Proposal #43 status: "approved"

# 2. Do your research
memories = search_memory("authentication patterns")
# ... investigate codebase ...

# 3. Create the ticket with your research findings
create_ticket_from_proposal(
  proposal_id: 43,
  title: "Implement OAuth authentication",
  description: "Based on research, we should use Devise OAuth gem...",
  ticket_type: "story"
)
# => Creates ticket and marks proposal #43 as "executed"
```

### Autonomous Task (Direct to create_ticket_from_proposal, Reviewer Approval)
```ruby
# 1. Wait for proposal approval (by reviewer)
# Proposal #44 status: "approved"

# 2. Do your research
memories = search_memory("documentation patterns")
# ... investigate codebase ...

# 3. Create the ticket (starts in backlog, not draft)
create_ticket_from_proposal(
  proposal_id: 44,
  title: "Update README with new docs",
  description: "Documentation needs to reflect recent API changes...",
  ticket_type: "task"
)
# => Creates ticket in backlog status
# => Marks proposal #44 as "executed"
```

### Skill Proposal (Direct to create_ticket_from_proposal)
```ruby
# 1. Wait for proposal approval (by human)
# Proposal #45 status: "approved"

# 2. Do your research
# ... understand skill requirements ...

# 3. Create a ticket for the skill file
create_ticket_from_proposal(
  proposal_id: 45,
  title: "Create code review helper skill",
  description: "Skill should help with PR review workflow...",
  ticket_type: "task"
)
# => Creates ticket and marks proposal #45 as "executed"

# 4. Create the skill file manually when working on the ticket
# Create .claude/skills/my-custom-skill/SKILL.md
```

## Error Handling

### Not Approved
```json
{
  "success": false,
  "error": "Forbidden",
  "message": "Can only execute approved proposals",
  "status": "pending"
}
```

### Already Executed
```json
{
  "success": false,
  "error": "Forbidden",
  "message": "Proposal already executed",
  "status": "executed"
}
```