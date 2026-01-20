---
name: proposal-execution
description: Use when executing approved proposals. Only memory_cleanup and test_gap proposals can be executed. Other types should use create_ticket_from_proposal directly.
---

# Proposal Execution

## Overview

Researchers can create proposals, but they cannot execute them directly - they need approval first. Once a proposal is **approved** by a human/reviewer, researchers can use `execute_proposal` to carry out the proposed action.

**Important:** Only `memory_cleanup` and `test_gap` proposals can be executed with `execute_proposal`. All other proposal types should use `create_ticket_from_proposal` directly after approval.

## When to Use

Use `execute_proposal` when:
- Your proposal has been **approved** (status = "approved")
- The proposal type is `memory_cleanup` or `test_gap`

## Proposal Types

### Executable Proposals (Use execute_proposal)
- `memory_cleanup`: Deletes memories immediately when executed
- `test_gap`: Creates a ticket automatically when executed (starts in backlog)

### Other Proposals (Use create_ticket_from_proposal directly)
- `task`: Requires research before ticket creation
- `autonomous_task`: Requires research before ticket creation (reviewer-approved)
- `skill_proposal`: Requires research before skill file creation
- `refactor`: Requires research before ticket creation
- `feature`: Requires research before ticket creation

**DO NOT use `execute_proposal` for these types.** Instead:
1. Wait for proposal approval (human or reviewer)
2. Do your research (investigate codebase, understand requirements)
3. Use `create_ticket_from_proposal` to create the ticket directly

## Withdrawing Proposals

Use `withdraw_proposal` to mark a proposal as withdrawn when it's no longer needed or has become obsolete.

```bash
withdraw_proposal(proposal_id: 42)
```

**Result:**
```json
{
  "success": true,
  "message": "Proposal withdrawn successfully",
  "proposal_id": 42,
  "title": "Obsolete proposal",
  "status": "withdrawn"
}
```

**Constraints:**
- Cannot withdraw already executed proposals
- Cannot withdraw already withdrawn proposals

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

### task, autonomous_task, refactor, feature, skill_proposal
**DO NOT use `execute_proposal` for these types.**

After approval, use `create_ticket_from_proposal` directly:
1. Wait for proposal approval
2. Do your research (investigate codebase, understand requirements)
3. Use `create_ticket_from_proposal` to create the ticket
4. The proposal will be marked as executed when the ticket is created

**Notes:**
- `autonomous_task` and `test_gap` can be approved by reviewer (not requiring human approval)
- Tickets from autonomous workflow proposals start in **backlog** status (skip draft)
- Tickets from human workflow proposals start in **draft** status

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

# 3. Execute the approved proposal
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

### Withdrawing an Obsolete Proposal
```ruby
# Proposal is no longer relevant
withdraw_proposal(proposal_id: 44)
# => Marks proposal #44 as "withdrawn"
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

### Wrong Proposal Type
```json
{
  "success": false,
  "error": "Forbidden",
  "message": "Proposal type 'task' should use create_ticket_from_proposal instead of execute_proposal. Only test_gap and memory_cleanup can be executed automatically.",
  "suggested_action": "Use create_ticket_from_proposal after completing your research"
}
```
