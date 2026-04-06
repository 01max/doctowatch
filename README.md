# Doctowatch

Periodically checks [Doctolib](https://www.doctolib.fr) for appointment availability and sends a Telegram notification when slots are found. Runs as a GitHub Actions cron job every 30 minutes.

Uses the [`toc_doc`](https://github.com/01max/toc_doc) gem to query the Doctolib API.

## How it works

1. Reads `config.yml`, which defines one or more watches (each top-level key is a watch)
2. For each watch, calls the Doctolib availability API
3. If slots are found, sends a Telegram message
4. If no slots, logs it and moves on — watches are independent

**Notification format:**

```
Doctowatch [dentist_paris]: slots found!

- Mon 7 Apr: 09:00, 10:30, 14:00
- Tue 8 Apr: 11:15

(5 slots total)
```

## Setup

### 1. Config

```sh
cp config.yml.example config.yml
```

Edit `config.yml` with your Doctolib IDs (visit motive, agenda, practice). You can find these in the Doctolib booking URL or via the `toc_doc` gem.

```yaml
dentist_paris:
  visit_motive_ids: 7767829
  agenda_ids: 1101600
  practice_ids: 377272
  start_date: today       # "today" or "2025-06-01"
  telehealth: false
  limit: 5                # optional, defaults to 5
```

### 2. Telegram bot

Create a `.env` file for local runs:

```sh
TELEGRAM_BOT_TOKEN=your_token
TELEGRAM_CHAT_ID=your_chat_id
```

### 3. Run locally

```sh
bundle install
DEV_MODE=1 ruby check.rb
```

`DEV_MODE=1` loads `.env` via dotenv.

## GitHub Actions

The workflow runs every 30 minutes. Add three repository secrets:

| Secret | Description |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token |
| `TELEGRAM_CHAT_ID` | Telegram chat ID to notify |
| `DOCTOWATCH_CONFIG` | Full contents of your `config.yml` |

> `config.yml` is gitignored. The `DOCTOWATCH_CONFIG` secret is written to the file at runtime before `check.rb` runs.

