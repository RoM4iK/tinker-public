name: researcher-digest
description: Send a strategic AI digest to the team via Telegram summarizing autonomous system activity.
----
# AI Digest

## Purpose
Keep the human team informed about the autonomous agent swarm's activity. Think like a **Lead Architect writing a daily standup update** for stakeholders who don't have time to check the dashboard.

## Your Task
Compose and send a concise, high-signal digest message via Telegram covering:
- **What's happening:** Active work, recent completions
- **What needs attention:** Pending proposals, blockers, escalations
- **What's coming:** Queued work, upcoming decisions

## Gathering Context
Use these tools to understand the current state:
- `get_status` - Project overview: ticket counts by status, agents availability
- `list_tickets` - Active (`in_progress`), blocked, recently completed (`done`)
- `list_proposals` - Pending and approved proposals awaiting action
- `list_members` - Agent availability (who's idle, who's busy)
- `search_memory` - Recent decisions, errors, friction points
- `list_agent_logs` - Recent agent actions (what actually happened)

GitHub context (via terminal):
- `gh pr list --state open` - Open PRs awaiting review/merge
- `gh pr list --state merged --limit 5` - Recently merged PRs

## Sending the Message
Call `send_telegram_message(message: "...")` with your composed digest.
- Use Markdown formatting.
- Be concise—this is for mobile reading.
- **IMPORTANT: Include clickable links for ALL referenced tickets, proposals, and PRs.**

## Quality Bar
- **High signal, low noise.** Skip trivial updates.
- **Actionable.** If something needs human attention, say so clearly.
- **Context-aware.** Reference specific ticket IDs, proposal titles.
- **Linked.** ALWAYS link resources with absolute URLs.
  - **Base URL:** Derive from your environment (e.g. `https://<project-name>.tinkerai.win`).
  - Tickets: `[#123](https://<project>.tinkerai.win/tickets/123)`
  - Proposals: `[Proposal #456](https://<project>.tinkerai.win/proposals/456)`
  - PRs: `[PR #789](https://github.com/OWNER/REPO/pull/789)`
- **Personality allowed.** A brief witty observation is welcome.
