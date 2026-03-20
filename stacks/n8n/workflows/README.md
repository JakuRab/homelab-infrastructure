# n8n Workflows

Importable workflow definitions for n8n. These are exported as JSON and can be imported via the n8n UI.

## SEO Crawl Daily Report

**File:** `seo-crawl-daily-report.json`

Compares the last two rows of a Google Sheets crawl export, sends the diff through Claude Haiku for analysis, and delivers the report via Telegram.

**Flow:**
```
Schedule (07:00 Warsaw) → Google Sheets (read A:T) → Code (diff last 2 rows) → HTTP Request (Claude API) → Telegram
```

### Prerequisites

You need three sets of credentials configured in n8n before importing:

#### 1. Google Sheets OAuth2

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a project (or use existing)
3. Enable the **Google Sheets API**
4. Create **OAuth 2.0 Client ID** (type: Web Application)
5. Add authorized redirect URI: `https://n8n.rabalski.eu/rest/oauth2-credential/callback`
6. In n8n: **Settings → Credentials → Add Credential → Google Sheets OAuth2 API**
7. Paste Client ID and Client Secret, then click **Connect** to authorize

#### 2. Anthropic API Key (Header Auth)

1. In n8n: **Settings → Credentials → Add Credential → Header Auth**
2. Configure:
   - **Name:** `x-api-key`
   - **Value:** your Anthropic API key (same one from `~/homelab-agents/daily-report/.env`)

#### 3. Telegram Bot

1. In n8n: **Settings → Credentials → Add Credential → Telegram API**
2. Configure:
   - **Bot Token:** same token as `TELEGRAM_BOT_TOKEN` from `~/homelab-agents/daily-report/.env`
   - This uses the existing @Red_Tower_bot ("Homelab Monitor")

### Import & Configure

1. Open n8n: https://n8n.rabalski.eu
2. **Workflows → Import from File** → select `seo-crawl-daily-report.json`
3. Open each node and assign the correct credentials:
   - **Read Crawl Data** → Google Sheets OAuth2 credential
   - **Claude Analysis** → Header Auth credential (Anthropic)
   - **Send to Telegram** → Telegram API credential
4. In the **Send to Telegram** node, set `chatId` to your Telegram chat ID
   (same `TELEGRAM_CHAT_ID` from `~/homelab-agents/daily-report/.env`)
5. **Save** and **Activate** the workflow

### Testing

- Click **Test Workflow** in the n8n editor to run it immediately
- Check each node's output to verify:
  - Google Sheets returns rows with the expected column headers
  - Code node produces a diff with `changesCount`
  - Claude API returns a report in `content[0].text`
  - Telegram sends successfully

### Customization

**Change schedule:** Edit the cron expression in "Daily 07:00 Warsaw" node. The timezone follows the n8n container's `GENERIC_TIMEZONE=Europe/Warsaw` setting.

**Change columns:** The Code node reads whatever columns Google Sheets returns. To include columns past T, just change the `range` option in the "Read Crawl Data" node (e.g., `A:Z`).

**More sophisticated analysis:** Edit the `systemPrompt` string in the "Compare Last Two Rows" Code node. The entire prompt and Claude model selection are in that single node, making it easy to:
- Ask for trend analysis across more rows (adjust the Code to look at last N rows instead of 2)
- Change the model (e.g., swap to `claude-sonnet-4-6-20250514` for deeper analysis)
- Add specific domain knowledge to the system prompt
- Request structured output (JSON) for downstream processing

**Skip report when no changes:** Add an IF node between "Compare Last Two Rows" and "Claude Analysis" that checks `{{ $json.changesCount > 0 }}`.

### Cost

~$0.005/run using Claude Haiku (similar to the daily homelab report).
