---
name: researcher-telegram-processor
description: Process incoming Telegram messages from humans and take appropriate actions (comments, ticket updates, knowledge articles, proposals, or replies).
---

# Researcher Telegram Processor

## Purpose

You have been activated because **the human has posted messages in Telegram**. Your job is to:

1. **Read and understand** what the human wants
2. **Take appropriate action** based on the message content
3. **Mark messages as read** when done

This is a **priority interrupt** - you should process these messages instead of your normal research cycle.

---

## Your Workflow

### Step 1: Fetch Messages

```ruby
get_telegram_messages(unread_only: true, limit: 50)
```

This returns:
- `messages` array with `content`, `from_user`, `created_at`
- `project_id` and `project_name`
- `message_count`

### Step 2: Analyze and Take Action

For each message, determine what the human wants and use the appropriate tools:

| Human wants... | Use this tool |
|----------------|---------------|
| **Question/clarification** about a ticket | `add_comment(ticket_id, content, "question")` |
| **Decision** or direction | `add_comment(ticket_id, content, "decision")` |
| **Feedback** on work in progress | `add_comment(ticket_id, content, "note")` |
| **New information** to remember | `store_memory(content, "fact", metadata: {...})` |
| **Instruction** or process change | `store_memory(content, "instruction", metadata: {...})` |
| **Knowledge** to document | Create `knowledge_article` (via proposal) |
| **General chat** or acknowledgment | `send_telegram_reply(text)` |

**Important context:**
- The human can reference tickets by number (e.g., "ticket #123")
- They may provide feedback, ask questions, or give instructions
- Not all messages require action - some are acknowledgments
- Use your judgment to determine the best response

### Step 3: Mark Messages as Read

After processing ALL messages:

```ruby
mark_telegram_messages_read(message_ids: [1, 2, 3, ...])
```

**Critical:** Collect all message IDs from Step 1 and mark them all as read at the end.

---

## Your Available Tools

**Telegram-specific:**
- `get_telegram_messages(unread_only: true, limit: 50)` - Fetch unread messages
- `mark_telegram_messages_read(message_ids: [...])` - Mark messages processed
- `send_telegram_reply(text)` - Reply to the human in Telegram

**Ticket actions:**
- `get_ticket(ticket_id)` - Get ticket details
- `add_comment(ticket_id, content, comment_type)` - Add comment (types: note, question, decision, code_review)
- `update_ticket(ticket_id, ...)` - Update ticket fields

**Memory & Knowledge:**
- `store_memory(content, memory_type, ticket_id, metadata)` - Store information
- `search_memory(query)` - Search existing memories
- `search_knowledge_articles(query)` - Search knowledge base

**Proposals:**
- `create_proposal(...)` - Suggest new tickets or changes (for knowledge articles, etc.)

---

## Decision Framework

**Does the message reference a specific ticket?**
- Yes → Add comment to that ticket
- No → Check if it's general feedback/instruction

**Is it a question?**
- Yes → Add as "question" comment OR reply via Telegram if it's general

**Is it a decision or directive?**
- Yes → Add as "decision" comment OR store as "instruction" memory

**Is it feedback or observation?**
- Yes → Add as "note" comment OR store as "fact" memory

**Is it worth documenting as knowledge?**
- Yes → Create a proposal for a knowledge article

**Is it just casual chat/acknowledgment?**
- Yes → Optionally reply via Telegram, then mark as read

---

## Example Interactions

**Example 1: Feedback on a ticket**
```
Human: "Ticket #84456 needs to handle the case where Telegram isn't configured"
Action: add_comment(ticket_id: 84456, content: "...", comment_type: "note")
```

**Example 2: New instruction**
```
Human: "From now on, always check for N+1 queries in new code"
Action: store_memory(content: "...", memory_type: "instruction")
```

**Example 3: Question**
```
Human: "What's the status of the proposal for refactoring the auth service?"
Action: add_comment(ticket_id: <proposal_ticket>, content: "...", comment_type: "question")
```

**Example 4: General chat**
```
Human: "Thanks for the update!"
Action: send_telegram_reply("You're welcome! Let me know if you need anything else.")
```

---

## Edge Cases

**No messages found?**
- This shouldn't happen (job only triggers you when messages exist)
- If it does, log and exit gracefully

**Can't understand the message?**
- Add a comment asking for clarification
- OR reply via Telegram asking for more details

**Message references multiple tickets?**
- Add comments to each relevant ticket
- Summarize the action taken in your memory log

**Message is ambiguous?**
- Make your best judgment based on context
- Store a memory noting the ambiguity
- Don't block - take reasonable action

---

## Completion

**You're done when:**
1. All unread messages have been processed
2. Appropriate actions taken (comments, memories, replies)
3. All messages marked as read
4. A memory log stored summarizing what you did

**Log format:**
```ruby
store_memory(
  content: "[TELEGRAM] Processed 3 messages. Added 2 comments, stored 1 instruction. Replied to 1 casual chat.",
  memory_type: "summary"
)
```

**Then STOP.** Do not proceed to normal research cycle. The next ping will handle that.
