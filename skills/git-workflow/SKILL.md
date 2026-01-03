---
name: git-workflow
description: Use for any git operations: fixing PRs, creating commits, creating branches, pushing changes. Handles proper branch management, commit conventions, and stacked PRs.
---

# Git Workflow - Complete Guide

## Golden Rules

1. **Never push to main**
2. **Fix PRs on their existing branch** - don't create new branches
3. **Stack phased work** - Phase N branches from Phase N-1
4. **Use conventional commits** - type(scope): subject
5. **Always include ticket ID** - in branch names AND PR titles

---

## Naming Conventions

### Branch Names
Format: `<type>/<id>-short-description`

Examples:
- `feature/123-user-auth`
- `fix/456-memory-leak`
- `refactor/789-api-structure`

### PR Titles
Format: `[#<id>] <type>(<scope>): <subject>`

Examples:
- `[#123] feat(auth): add OAuth2 login support`
- `[#456] fix(database): resolve connection pool timeout`
- `[#789] refactor(api): simplify response handling`

---

## Scenario 1: Fixing an Existing PR

When user says: "Fix PR #33" or "Update pull request 45" or "Modify #123"

### Steps

1. **Get the PR branch:**
```bash
gh pr view <PR_NUMBER> --json headRefName --jq '.headRefName'
```
Save this branch name - use it for ALL operations.

2. **Checkout the PR branch:**
```bash
git fetch origin
git checkout <branch_name>
```

3. **Make changes** using Edit/Write tools

4. **Commit with proper format:**
```bash
git add <files>
git commit -m "fix(scope): description of fix"
git push origin <branch_name>
```

5. **No new PR needed** - same PR URL

### Example
```
User: "Fix the failing tests in PR #33"

1. gh pr view 33 --json headRefName -> "feature/81-ui-foundation"
2. git checkout feature/81-ui-foundation
3. [fix test files]
4. git commit -m "fix(tests): resolve assertion failures in dashboard spec"
5. git push origin feature/81-ui-foundation
```

---

## Scenario 2: Creating a New Feature (Single PR)

When user says: "Implement X" or "Add feature Y" (no mention of phases/stacking)

**IMPORTANT**: You must know the ticket ID before proceeding. Ask the user if not provided.

### Steps

1. **Start from main:**
```bash
git checkout main
git pull origin main
```

2. **Create feature branch with ticket ID:**
```bash
git checkout -b feature/<id>-short-description
```

3. **Make changes** using Edit/Write tools

4. **Commit and push:**
```bash
git add -A
git commit -m "feat(scope): description"
git push -u origin feature/<id>-short-description
```

5. **Create PR with ticket ID in title:**
```bash
gh pr create --base main --title "[#<id>] feat(scope): description"
```

---

## Scenario 3: Creating Stacked PRs (Phased Epic)

When user says: "Create Phase 1, Phase 2, Phase 3" OR working on epic subtasks sequentially

**IMPORTANT**: Each subtask has its own ticket ID. Use the appropriate ticket ID for each phase.

### Critical Concept
Each phase builds on the PREVIOUS phase, NOT main.

```
main <- phase-1 <- phase-2 <- phase-3
```

### Phase 1 (Foundation)
```bash
git checkout main
git pull origin main
git checkout -b feature/<id1>-phase1-description
# Make changes
git commit -m "feat(phase1): description"
git push -u origin feature/<id1>-phase1-description
gh pr create --base main --title "[#<id1>] feat(scope): Phase 1 - Description"
```

### Phase 2 (Builds on Phase 1)
```bash
# IMPORTANT: Branch from phase-1, NOT main
git checkout feature/<id1>-phase1-description
git pull origin feature/<id1>-phase1-description
git checkout -b feature/<id2>-phase2-description
# Make changes
git commit -m "feat(phase2): description"
git push -u origin feature/<id2>-phase2-description
gh pr create --base feature/<id1>-phase1-description --title "[#<id2>] feat(scope): Phase 2 - Description"
```

### Phase 3+ (Continue stacking)
```bash
git checkout feature/<id2>-phase2-description
git checkout -b feature/<id3>-phase3-description
# ... continue pattern
```

### After Phase 1 Merges to Main
```bash
git checkout main && git pull
git checkout feature/<id2>-phase2-description
git rebase main
git push -f origin feature/<id2>-phase2-description
```
Now Phase 2 is based on updated main.

---

## Commit Message Format

Always use:

```
<type>(<scope>): <subject>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `chore`: Maintenance tasks

### Rules
- Subject: imperative mood, max 50 chars, no period
- Examples:
  - "fix(auth): prevent SQL injection in login"
  - "feat(dashboard): add real-time agent status"
  - "test(models): add ticket dependency coverage"

---

## Quick Reference

| Task | Base Branch | PR Base |
|------|-------------|---------|
| New feature | main | main |
| Fix PR #X | PR's branch | (no new PR) |
| Phase 1 | main | main |
| Phase 2 | phase-1 branch | phase-1 branch |
| Phase 3 | phase-2 branch | phase-2 branch |

---

## GitHub Backlinks in PRs

When creating PRs, **always include backlinks** to application resources so users can navigate from GitHub back to the app.

### When to Add Backlinks

- **Worker submitting work** → Link to ticket and agent session
- **Reviewer commenting** → Link to ticket being reviewed
- **Any GitHub interaction** → Include relevant app URLs

### URL Format

Use the standard Tinker URL pattern: `https://{project_name}.tinkerai.win`

| Resource | URL Pattern |
|----------|-------------|
| Ticket | `https://{project}.tinkerai.win/tickets/{id}` |
| Agent Session | `https://{project}.tinkerai.win/agent_sessions/{id}` |
| Logs | `https://{project}.tinkerai.win/dashboard/logs` |
| Kanban | `https://{project}.tinkerai.win/dashboard/kanban` |

For the main tinker project: `https://tinker.tinkerai.win`

### PR Description Template

```bash
gh pr create --base main --title "[#<id>] feat(scope): description" --body '## Summary

Brief description of changes.

## Changes

- Change 1
- Change 2

---

**Application Links:**
[View Ticket](https://tinker.tinkerai.win/tickets/42) | [View Session](https://tinker.tinkerai.win/agent_sessions/123)
'
```

### Getting Project Name

The project name is available via the `get_ticket` MCP tool response. For most Tinker deployments, use `tinker`:

```bash
# Get ticket info to confirm project
ticket_info=$(get_ticket ticket_id: 42)
project_name="tinker"  # Default for main tinker project

ticket_url="https://${project_name}.tinkerai.win/tickets/42"
```

---

## Critical DOs and DON'Ts

| DO | DON'T |
|-----|-------|
| Checkout PR branch when fixing | Create new branch for PR fixes |
| Stack phases (phase-2 from phase-1) | Branch all phases from main |
| Use conventional commit format | Write vague commit messages |
| Push to the branch you're working on | Push to random branches |
| Set correct PR base for stacked PRs | Base all PRs on main |
| Include ticket ID in branch names | Use generic branch names |
| Include ticket ID in PR titles | Create PRs without ticket reference |
| Add backlinks in PR bodies | Create PRs without application links |
