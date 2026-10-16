# Two-way watchdog: your server and Home Assistant watch each other

## The problem

You build alerts on your home server ("backup failed", "disk dying") and send them through Home
Assistant's phone notifications. It works, until Home Assistant itself is down. Then every alert fails
silently, and the outage you most need to hear about is the one you never hear about.

The mirror problem: if the server dies, its scripts die with it, so nothing reports that either.

## The fix

Three pieces:

| Direction | How | Alerts via |
|---|---|---|
| HA watches the server | The server sets a timestamp helper in HA every 10 min (`heartbeat.sh`). An HA automation fires if it goes 30 min without an update. | HA phone push |
| Server watches HA | `ha-watch.sh` checks `/api/` every 10 min. Three failures in a row send one email; recovery sends another. | Email (not HA) |
| Any push that fails | `common/notify.sh` falls back to email automatically. | Email |

Email goes through any normal SMTP account, so the backup channel has nothing to do with Home Assistant.

## Setup

1. Copy the kit to the server (for example `~/ha-community-kit`). Install `jq`, `curl`, `python3`.
2. Copy `common/config.example.env` to `~/.config/ha-kit.env`, fill it in, `chmod 600` it.
3. Put your HA long-lived token in the file named by `HA_TOKEN_FILE` and your SMTP app password in
   `SMTP_PASS_FILE`. Both `chmod 600`.
4. In HA, create the two helpers and paste `heartbeat-automation.yaml` (instructions at the top of it).
5. Cron (`crontab -e`):
   ```
   */10 * * * * $HOME/ha-community-kit/01-two-way-watchdog/heartbeat.sh
   */10 * * * * $HOME/ha-community-kit/01-two-way-watchdog/ha-watch.sh
   ```

## Test it before you trust it

- **Email path:** `python3 common/email-alert.py "test" "hello"` and check your inbox (and spam).
- **HA watching the server:** in Developer tools > Actions, run `input_datetime.set_datetime` on the
  heartbeat helper with a time an hour ago. You should get "gone silent" within a minute; run
  `heartbeat.sh` and you should get "checking in again".
- **Server watching HA:** copy `ha-watch.sh`, point the copy at a hostname that does not exist and a
  temporary `STATE_DIR`, and run it four times: no email on runs 1 and 2, one email on run 3, nothing on run 4.
- **Push fallback:** run a copy of `notify.sh` with a bad `HA_URL`; the message should arrive by email.

## Known limits

- If you revoke the SMTP app password, email fails quietly. Failures land in `$STATE_DIR/*.log`.
- One alert per outage on purpose. A flapping connection does not spam you.
