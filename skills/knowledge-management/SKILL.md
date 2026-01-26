# Knowledge Management Skill

## description
Interact with the Knowledge Base. Create, update, search, and manage persistent long-term knowledge articles.

## tools
- create_knowledge_article
- update_knowledge_article
- search_knowledge_articles
- get_knowledge_article
- list_knowledge_articles
- get_version_history
- link_ticket_to_knowledge

## usage

### When to use
- **Troubleshooting:** Document recurring errors, setup issues, and their fixes (`category: project_knowledge` tagged `troubleshooting`).
- **Instructions:** Store human directives, workflow standards, and project-specific rules (`category: project_knowledge` tagged `pattern` or `fact`).
- **Architecture:** Document decisions (ADRs) and system design (`category: project_knowledge` tagged `architecture` or `decision`).
- **Gotchas:** Document non-obvious behaviors or sharp edges (`category: project_knowledge` tagged `gotcha`).
- **Agent State:** Document long-term state for agents (`category: agent_state_*`).
- **Skill Hints:** Document dynamic skill behaviors (`category: skill_hint`).

### When NOT to use
- Do NOT use to track specific tasks or tickets (use Tickets for work).
- Do NOT use for ephemeral information that is only relevant to a single PR.
- Do NOT use for task lists or backlogs.

### Creating Articles
- **Purpose:** Create articles to persist knowledge for future Planner/Researcher agents.
- Always search first to avoid duplicates.
- Use descriptive titles.
- Categorize correctly: 'project_knowledge', 'agent_state_worker', 'agent_state_reviewer', 'agent_state_researcher', 'agent_state_planner', 'skill_hint'.
- Write clear markdown content.

### Updating Articles
- Read the article first.
- Provide a clear `change_summary`.
- Ensure continuity of information.
