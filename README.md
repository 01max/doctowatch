# Doctowatch

Periodically checks [Doctolib](https://www.doctolib.fr) for appointment availability and sends a Telegram notification when slots are found or change. Runs as a GitHub Actions cron job every 30 minutes on a self-hosted runner.

Uses the [`toc_doc`](https://github.com/01max/toc_doc) gem to query the Doctolib API.

## How it works

1. Reads `config.yml`, which defines one or more watches (each top-level key is a watch)
2. Downloads the previous run's report to detect changes
3. For each watch, calls the Doctolib availability API
4. If slots are found **and differ from the previous run**, sends a Telegram message
5. If no slots, or slots are unchanged, logs it and moves on — watches are independent
6. Saves a `report.json` artifact with the run results

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
bundle exec ruby check.rb
```

`.env` is loaded automatically outside of CI via dotenv.

## GitHub Actions

The workflow runs every 30 minutes on a self-hosted runner (required — Doctolib blocks GitHub-hosted runner IPs). Add three repository secrets:

| Secret | Description |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token |
| `TELEGRAM_CHAT_ID` | Telegram chat ID to notify |
| `DOCTOWATCH_CONFIG` | Full contents of your `config.yml` |

> `config.yml` is gitignored. The `DOCTOWATCH_CONFIG` secret is written to the file at runtime before `check.rb` runs.

### Self-hosted runner

The workflow requires a self-hosted runner with a residential IP. The recommended setup is a Docker container using [`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner) with these env vars:

| Variable | Value |
|---|---|
| `REPO_URL` | `https://github.com/<you>/doctowatch` to __your__ fork|
| `RUNNER_TOKEN` | Token from repo Settings > Actions > Runners |
| `RUNNER_NAME` | Any name |
| `LABELS` | `self-hosted` |
| `DISABLE_AUTOMATIC_DEREGISTRATION` | `true` |

