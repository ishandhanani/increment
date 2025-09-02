# Inboxy 📬

A powerful Gmail inbox cleanup tool that helps you analyze, organize, and declutter your email efficiently using the Gmail API.

## Features

- **📊 Inbox Discovery**: Analyze your inbox with detailed statistics

  - Top senders and domains (last 6 months)
  - Category breakdowns (promotions, social, updates, forums)
  - Age-based message counts
  - Large attachments and file analysis
  - Newsletter detection via List-Unsubscribe headers

- **🔍 Smart Preview**: Preview messages matching Gmail query syntax before taking action

- **🗑️ Bulk Operations**:

  - Permanently delete messages (bypasses trash)
  - Archive messages (remove from inbox)
  - Batch processing with progress indicators

- **⚙️ Filter Management**: Create Gmail filters to automatically delete or archive future emails from specific senders

## Setup

### Prerequisites

- Python 3.11+
- Gmail account with API access enabled
- Google Cloud Console project with Gmail API enabled

### Installation

1. **Enable Gmail API**:

   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable the Gmail API
   - Create OAuth 2.0 credentials (Desktop application type)
   - Download the credentials file as `credentials.json` in the project directory

2. **Run the script**:
   ```bash
   python clean.py discover
   ```
   On first run, it will open your browser for OAuth consent and save the token to `token.json`.

### Dependencies

The script uses PEP 723 inline metadata. Dependencies are automatically managed:

- `google-api-python-client`
- `google-auth-httplib2`
- `google-auth-oauthlib`
- `textual`

## Usage

### Discover Your Inbox

Get comprehensive inbox statistics and insights:

```bash
python clean.py discover
```

Example output:

```
📬 INBOX: 15,432 total, 1,247 unread

— Top senders in INBOX (last 6 months) —
  127  newsletters@company.com
   89  noreply@github.com
   56  notifications@slack.com

Top domains:
  245  github.com
  189  company.com
  134  slack.com

Newsletters (List-Unsubscribe detected) in sample: 1,432
Category promotions  : 3,245
Category social      : 892
Category updates     : 2,156
Older than   1y: 8,934
Larger than 5MB: 23
```

### Preview Messages

Preview messages matching a Gmail query before taking action:

```bash
python clean.py preview --query "from:noreply@company.com older_than:6m"
python clean.py preview --query "category:promotions older_than:3m" --sample 20
```

### Bulk Delete

Permanently delete messages (bypasses trash):

```bash
python clean.py delete --query "category:promotions older_than:1y"
```

⚠️ **Warning**: This permanently deletes emails. You'll be prompted to confirm with "yes".

### Bulk Archive

Remove messages from inbox (archive):

```bash
python clean.py archive --query "from:newsletters@company.com older_than:3m"
```

### Create Filters

Automatically handle future emails from specific senders:

```bash
# Auto-delete future emails from sender
python clean.py filter --from "spam@company.com" --action delete

# Auto-archive future emails from sender
python clean.py filter --from "newsletters@company.com" --action archive
```

## Gmail Query Syntax

Use Gmail's powerful search syntax for precise targeting:

| Query                     | Description                          |
| ------------------------- | ------------------------------------ |
| `from:user@domain.com`    | From specific sender                 |
| `to:me`                   | Sent to you                          |
| `subject:"meeting notes"` | Specific subject                     |
| `older_than:6m`           | Older than 6 months (d/w/m/y)        |
| `newer_than:1w`           | Newer than 1 week                    |
| `category:promotions`     | Promotional emails                   |
| `category:social`         | Social network emails                |
| `category:updates`        | Updates/notifications                |
| `category:forums`         | Forum/mailing list emails            |
| `larger:5M`               | Larger than 5MB                      |
| `has:attachment`          | Has attachments                      |
| `is:unread`               | Unread messages                      |
| `in:inbox`                | In inbox (default for most commands) |

Combine queries with `AND`, `OR`, and parentheses:

```bash
python clean.py preview --query "category:promotions AND older_than:6m"
python clean.py delete --query "(from:old-newsletter.com OR from:spam-site.com) older_than:1m"
```

## Safety Features

- **Confirmation prompts** before destructive operations
- **Preview mode** to see what will be affected
- **Progress indicators** for batch operations
- **Gentle API usage** with built-in rate limiting
- **Error handling** for individual message failures

## File Structure

- `clean.py` - Main application script
- `token.json` - OAuth credentials (generated on first run)
- `credentials.json` - OAuth client secrets (you provide this)

## Recommended Workflow

1. **Start with discovery**: `python clean.py discover`
2. **Preview before action**: Always preview queries first
3. **Start small**: Test with small batches before bulk operations
4. **Create filters**: Set up automation for recurring cleanup
5. **Regular maintenance**: Run discovery monthly to stay on top of inbox growth

## Troubleshooting

- **"Missing credentials.json"**: Download OAuth credentials from Google Cloud Console
- **"Insufficient permissions"**: The script requests full Gmail scope for delete/filter operations
- **Rate limiting**: Built-in delays prevent API quota issues
- **Token expiry**: Script automatically refreshes tokens as needed

## Security Note

This tool requires full Gmail access to perform delete operations and create filters. Your credentials are stored locally in `token.json` and never transmitted elsewhere.
