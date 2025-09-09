# Inboxy

AI-powered Gmail client for the command line. Get a morning digest of what actually matters, with direct links to open emails in Gmail.

## Features

- **Smart Inbox View** - See your emails like Gmail, but in the terminal
- **AI-Powered Digests** - Get a morning report of urgent items and what can be deleted
- **Direct Gmail Links** - Click any email in the digest to open it in Gmail
- **Bulk Management** - Preview and delete/archive emails using Gmail search syntax
- **Smart Caching** - 1-hour cache to avoid redundant API calls

## Installation

```bash
# Navigate to inboxy directory
cd inboxy

# Install with uv (creates venv and installs dependencies)
uv sync

# Install as editable package for development
uv pip install -e .
```

## Configuration

### 1. Gmail API Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Gmail API
4. Create OAuth 2.0 credentials (Desktop application)
5. Download as `credentials.json` to the inboxy directory

### 2. OpenRouter API
1. Get your API key at [openrouter.ai](https://openrouter.ai/keys)
2. Add to `.env` file

### 3. Environment Setup
```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your API keys
# Required: OPENROUTER_API_KEY
# Optional: Email settings for digest delivery
```

## Usage

After installation with `uv sync`, you can run inboxy in several ways:

### Using uv run (Recommended)
```bash
# View inbox
uv run inboxy

# Generate digest
uv run inboxy digest

# Preview emails
uv run inboxy preview --query "from:newsletter@example.com"
```

### After installing as package
```bash
# If you ran: uv pip install -e .
inboxy
inboxy digest
inboxy preview --query "older_than:30d"
```

### Direct Python execution
```bash
uv run python inboxy.py
uv run python inboxy.py digest --send
```

## Commands

### View Inbox (default)
```bash
uv run inboxy
```
Shows your inbox with sender, subject, and date - just like Gmail.

### AI Digest
```bash
# Generate digest
uv run inboxy digest

# Email it to yourself
uv run inboxy digest --send

# Force fresh data (skip cache)
uv run inboxy digest --fresh
```

The digest shows:
- 🔴 **URGENT items** that need response before starting your day
- 🗑️ **Deletable emails** grouped by sender with exact commands to remove them
- Direct Gmail links to open any email

### Preview & Manage

#### Using Cleanup Presets
```bash
# List available cleanup presets
uv run inboxy preview --list-presets

# Preview promotional emails
uv run inboxy preview --query promotions

# Delete old promotional emails (older than 7 days)
uv run inboxy preview --query old-promotions --delete

# Clean up old noise (promotions/social older than 7 days)
uv run inboxy preview --query noise --delete

# Archive ancient emails (older than 1 year)
uv run inboxy preview --query ancient --archive
```

#### Custom Gmail Searches
```bash
# Preview any Gmail search
uv run inboxy preview --query "from:newsletter@example.com"
uv run inboxy preview --query "older_than:30d"

# Delete emails
uv run inboxy preview --query "category:promotions" --delete

# Archive emails
uv run inboxy preview --query "older_than:90d" --archive
```

#### Available Cleanup Presets

| Preset | Description | Gmail Query |
|--------|-------------|-------------|
| `promotions` | All promotional emails | `category:promotions` |
| `social` | Social media notifications | `category:social` |
| `newsletters` | Emails with unsubscribe headers | `list:*` |
| `old-promotions` | Promotions older than 7 days | `category:promotions older_than:7d` |
| `old-social` | Social emails older than 30 days | `category:social older_than:30d` |
| `noise` | Promotions/social older than 7 days | `(category:promotions OR category:social) older_than:7d` |
| `old-noise` | All categories older than 30 days | `(category:promotions OR category:social OR category:updates) older_than:30d` |
| `unread-old` | Unread emails older than 30 days | `is:unread older_than:30d` |
| `ancient` | Emails older than 1 year | `older_than:1y` |

## Morning Automation

Add to your crontab for daily 7 AM digest:
```bash
crontab -e
# Add this line (adjust path as needed):
0 7 * * * cd /path/to/inboxy && uv run inboxy digest --send
```

## Gmail Search Syntax

| Query | Description |
|-------|-------------|
| `from:person@email.com` | From specific sender |
| `subject:meeting` | Subject contains "meeting" |
| `is:unread` | Unread emails |
| `has:attachment` | Has attachments |
| `larger:5M` | Larger than 5MB |
| `older_than:30d` | Older than 30 days |
| `newer_than:1d` | From last 24 hours |
| `category:promotions` | Promotional emails |

## Development

```bash
# Run tests
uv run pytest

# Format code
uv run black src/ inboxy.py
uv run ruff check src/ inboxy.py

# Type checking
uv run mypy src/
```

## Project Structure

```
inboxy/
├── inboxy.py              # CLI entry point
├── src/
│   └── inboxy/
│       ├── __init__.py    # Package exports
│       ├── models.py      # Data models
│       ├── gmail.py       # Gmail API client
│       ├── ai.py          # AI analysis
│       └── digest.py      # Digest generation
├── pyproject.toml         # Project configuration
├── .env.example           # Environment template
└── README.md              # This file
```

## Environment Variables

```bash
# Required
OPENROUTER_API_KEY=sk-or-v1-xxxxx

# Optional - for email digests
DIGEST_RECIPIENT_EMAIL=you@gmail.com
SMTP_USER=you@gmail.com
SMTP_PASSWORD=app-specific-password
```

## License

MIT