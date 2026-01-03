---
name: review-workflow
description: Use when reviewing pull requests. Covers PR examination, code quality checks, adding feedback, and pass/fail decisions.
---

# Code Review Workflow

## PROCESS

1. **Get ticket details:**
```bash
get_ticket(ticket_id: X)
```

2. **Review the PR at pull_request_url:**
```bash
gh pr view {PR_NUMBER}
gh pr diff {PR_NUMBER}
```

3. **Search for existing spec patterns BEFORE claiming tests are missing:**

   **CRITICAL:** Before asserting that "no tests exist" for a component, you MUST search the codebase for existing spec files. Incorrectly claiming no tests exist will cause your review to be rejected.

   **NEVER claim "no tests in this area" without first searching spec directories.**

4. **Run the test suite BEFORE any approval:**
```bash
bundle exec rspec
```

   **CRITICAL:** If ANY tests fail, you MUST fail_audit. Do not approve with failing tests.

5. **Detect missing specs based on changes:**

   Check the PR diff for file changes. For each file pattern, verify matching spec files exist.

6. **Check:**
   - All tests pass (run full test suite)
   - Test coverage matches changes (no missing specs)
   - Code quality and style
   - Implementation matches ticket requirements
   - No breaking changes

8. **Add feedback to Tinker:**
```bash
add_comment(
  ticket_id: X,
  content: "## Code Review\n\n[Include test results, spec coverage check, findings]",
  comment_type: "code_review"
)
```

9. **Add feedback to GitHub:**
```bash
gh pr comment {PR_URL} --body "Your feedback here"
```

10. **Set Reviewer Confidence and Decide:**

Set your confidence (0-100) in the review quality:

| Range | Label | Use Case |
|-------|-------|----------|
| 0-33 | Low | Uncertain about review quality, limited time |
| 34-66 | Medium | Standard review, reasonable confidence |
| 67-100 | High | Thorough review, all aspects covered |

**PASS** (code acceptable, all tests pass, no missing specs):
```bash
# Set reviewer confidence before passing
update_ticket(
  ticket_id: X,
  working_memory: { "reviewer_confidence" => 80 }
)
transition_ticket(ticket_id: X, event: "pass_audit")
```

**FAIL** (issues found, tests fail, or missing specs):
```bash
# Set reviewer confidence before failing
update_ticket(
  ticket_id: X,
  working_memory: { "reviewer_confidence" => 90 }
)
transition_ticket(ticket_id: X, event: "fail_audit")
```

11. **Add the "tinker-reviewed" label to the PR:**
```bash
# Ensure label exists (create if missing)
gh label create "tinker-reviewed" --color "0E8A16" --description "PR reviewed by Tinker reviewer agent" 2>/dev/null || true

# Add the label to the PR
gh pr edit {PR_NUMBER} --add-label "tinker-reviewed"
```

12. **Mark yourself idle:**
```bash
mark_idle()
```

## ABSOLUTE RULES

- **DO:** Search for existing spec patterns BEFORE claiming "no tests exist"
- **DO:** Run `bundle exec rspec` BEFORE ANY approval
- **DO:** Reject PRs with failing tests - use fail_audit immediately
- **DO:** Detect and flag missing specs before approval
- **DO:** Add code_review comments before fail_audit
- **DO:** Explicitly call out what tests/specs are missing
- **DO:** Check test coverage matches the code changes
- **DO:** Look for security issues
- **DO:** Add "tinker-reviewed" label to PR after completing review (pass or fail)
- **DO NOT:** Use gh pr review --approve (can't approve own PR)
- **DO NOT:** Write code to fix issues
- **DO NOT:** Use "approve" transition (for humans only)
- **DO NOT:** Approve PRs where tests were not run
- **DO NOT:** Skip adding the "tinker-reviewed" label after review

## Review Checklist Template

When reviewing, your code_review comment should include:

```
## Code Review

### Spec Pattern Search (REQUIRED)
- Searched for existing spec patterns: `find spec -name "*spec.rb" | sort`
- Found existing spec files: [list what exists]
- Similar patterns found: [e.g., ticket_workflow_spec.rb for ticket-related changes]

### Test Results
- Test suite run: `bundle exec rspec`
- Results: X examples, Y failures, Z pending

### Spec Coverage Check
- Files changed: [list from PR diff]
- Required specs found: [list present specs]
- Missing specs:
  - spec/features/[name]_spec.rb - MISSING (for UI changes)
  - spec/requests/[name]_spec.rb - MISSING (for controller changes)
  - etc.

### Findings
- Code quality: [observations]
- Security: [any issues found]
- Implementation: [matches ticket requirements?]
- Breaking changes: [any?]

### Decision
PASS / FAIL - [reason]
```

## Example: Proper Rejection for Missing Tests

```
## Code Review

### Spec Pattern Search (REQUIRED)
- Searched for existing spec patterns: `find spec -name "*spec.rb" | sort`
- Found existing spec files:
  - spec/features/ticket_workflow_spec.rb
  - spec/features/kanban_board_spec.rb
  - spec/features/sessions_page_spec.rb
  - spec/features/approvals_spec.rb
  - spec/features/dashboard_spec.rb
  - spec/features/debug_dashboard_spec.rb
  - spec/features/multi_terminal_page_spec.rb
  - spec/features/terminal_page_spec.rb
- Similar patterns found: Feature specs exist for similar UI components

### Test Results
- Test suite run: `bundle exec rspec`
- Results: 31 examples, 0 failures

### Spec Coverage Check
- Files changed:
  - app/views/debug/dashboard.html.erb
  - app/views/sessions/index.html.erb
  - app/views/terminal/index.html.erb

- Required specs found: NONE (but patterns exist in spec/features/)

- Missing specs:
  - spec/features/debug_dashboard_spec.rb - MISSING (pattern exists)
  - spec/features/sessions_page_spec.rb - MISSING (pattern exists)
  - spec/features/terminal_page_spec.rb - MISSING (pattern exists)

### Findings
- Code quality: UI components added but no feature specs to verify they work
- Security: No issues detected
- Implementation: UI changes present but untested

### Decision
**FAIL - Missing Tests**

Action Required:
Add feature specs for all UI components before this can be approved.
Follow existing patterns in spec/features/ (e.g., ticket_workflow_spec.rb for ticket-related flows).
```
