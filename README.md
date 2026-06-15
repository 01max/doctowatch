# Doctowatch

Periodically checks [Doctolib](https://www.doctolib.fr) for appointment availability and sends a Telegram notification when slots are found or change. Runs as a GitHub Actions cron job every 30 minutes on a self-hosted runner.

Uses the [`toc_doc`](https://github.com/01max/toc_doc) gem to query the Doctolib API.

## Disclaimer

Using this software is not aligned with Doctolib's Terms of Service. This project is provided for research and entertainment purposes only. You are responsible for ensuring that any use complies with applicable laws, policies, and third-party terms.

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
  booking_slug: medecin-generaliste/paris/docteur-jean-dupont  # optional, used to build the booking URL button
  start_date: today                  # "today" or "2025-06-01"
  telehealth: false
  limit: 5                           # optional, defaults to 5
  telegram_chat_id: "123456789"      # optional, overrides TELEGRAM_DEFAULT_CHAT_ID
```

All keys except `visit_motive_ids`, `agenda_ids`, and `practice_ids` are optional.

### 2. Telegram bot

Create a `.env` file for local runs:

```sh
TELEGRAM_BOT_TOKEN=your_token
TELEGRAM_DEFAULT_CHAT_ID=your_chat_id
```

`TELEGRAM_DEFAULT_CHAT_ID` is the fallback chat used when a watch doesn't set `telegram_chat_id` in `config.yml`.

### 3. Run locally

```sh
bundle install
bundle exec ruby check.rb
```

`.env` is loaded automatically outside of CI via dotenv.

## Telegram commands

Telegram sends webhook requests to [`telegram-gh-action-dispatcher`](https://github.com/01max/telegram-gh-action-dispatcher), a Cloudflare Worker that validates the chat and triggers this repository's `Telegram User Command` workflow via `repository_dispatch`.

- `/disable` — disables the check workflow
- `/enable` — re-enables the check workflow
- `/config` — replies with the current `config.yml`

The command workflow runs on GitHub-hosted runners because it only calls GitHub and Telegram APIs. The Doctolib availability check remains on the self-hosted runner, so `/enable` can still work even if the Unraid runner has gone idle or the check workflow is disabled.

## GitHub Actions

The availability workflow runs every 30 minutes on a self-hosted runner (required — Doctolib blocks GitHub-hosted runner IPs). The command workflow is triggered by the Cloudflare Worker and runs on `ubuntu-latest`. Add three repository secrets:

| Secret | Description |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token |
| `TELEGRAM_DEFAULT_CHAT_ID` | Telegram chat ID to notify |
| `DOCTOWATCH_CONFIG` | Full contents of your `config.yml` |

> `config.yml` is gitignored. The `DOCTOWATCH_CONFIG` secret is written to the file at runtime before `check.rb` runs.

### Self-hosted runner

The availability workflow requires a self-hosted runner with a residential IP. The recommended setup is a Docker container using [`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner) with an Unraid restart policy of `unless-stopped` or `always`.

Use a long-lived GitHub token and let the container request short-lived runner registration tokens when it starts. Do not use the one-time `RUNNER_TOKEN` from Settings > Actions > Runners for an always-on container; that token is short-lived and will fail after a later restart.

| Variable | Value |
|---|---|
| `REPO_URL` | `https://github.com/<you>/doctowatch` to __your__ fork|
| `RUNNER_SCOPE` | `repo` |
| `ACCESS_TOKEN` | Fine-grained GitHub PAT that can administer this repository's self-hosted runners |
| `RUNNER_NAME` | Any name |
| `LABELS` | `self-hosted` |
| `DISABLE_AUTOMATIC_DEREGISTRATION` | `true` |
| `CONFIGURED_ACTIONS_RUNNER_FILES_DIR` | Persistent path such as `/runner-data` to avoid re-registering on every start |

Persist `CONFIGURED_ACTIONS_RUNNER_FILES_DIR` to appdata, for example `/mnt/user/appdata/github-runner/doctowatch:/runner-data`, so Unraid restarts do not erase the runner configuration.
