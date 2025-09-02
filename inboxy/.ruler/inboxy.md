# AI Guidelines for @clean.py

- This script is a CLI tool for Gmail inbox cleanup and stats.
- Auth is handled via OAuth2; token.json is cached.
- Main features:
  - Discover: show top senders, domains, and newsletter stats.
  - Preview: sample messages for any Gmail search query.
  - Delete: permanently delete messages by query (bypasses Trash).
  - Archive: remove INBOX label (archive) by query.
  - Filter: create server-side Gmail filters for sender/action.
- Uses Google API client, works in batch for efficiency.
- All destructive actions require explicit confirmation.
- Designed for hacking, not for production automation.
- See code for details; most logic is in discover(), preview(), delete_by_query(), archive_by_query(), and create_filter().
