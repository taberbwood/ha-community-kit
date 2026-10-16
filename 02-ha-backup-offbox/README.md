# Copy Home Assistant's backups off the box (and the "partial" trap)

## The problem

HA's automatic backups land on the HA machine's own disk. If that disk dies, the backups die with it.
So you write a script to pull the newest backup onto another machine. A common first version selects
backups with `type == "full"`.

**That version silently copies nothing new, forever.** Supervisor reports every backup created by HA's
built-in automatic backup feature as `type: "partial"`, even when it contains everything: core, database,
all add-ons, all folders. Your script keeps finding the last *manual* full backup, logs "already have it",
and looks healthy.

How to check yours: list backups over the websocket API and look at `type` next to `content`:

```
python3 common/ha-ws.py '{"type":"supervisor/api","endpoint":"/backups","method":"get"}' \
  | jq -c '.result.backups[] | {slug, name, date, type, content}'
```

You will likely see your nightly backups as `"type":"partial"` with `"homeassistant":true`.

## The fix

Select on content, not type:

```
jq '.result.backups | map(select(.content.homeassistant == true)) | sort_by(.date) | last'
```

`pull-ha-backup.sh` does that, checks the newest backup is under 2 days old (so a stopped backup schedule
alerts you), downloads it, verifies the archive opens, and keeps the newest 14.

## Two more things worth knowing

- **Supervisor REST calls answer 401** with a normal long-lived token (`/api/hassio/backups` and friends).
  The websocket command `supervisor/api` works with the same token, hence `common/ha-ws.py`. The
  download URL `/api/hassio/backups/<slug>/download` is the exception: it works over REST.
- **Automatic backups contain your integration credentials** (cloud tokens for PSN, Xbox and so on).
  Consider turning on backup encryption in HA, and keep the copies `chmod 600` in a `700` folder.

## Setup

1. Common setup from `01-two-way-watchdog/README.md` steps 1 to 3 (config file, token).
2. `pip install websocket-client` (or `apt install python3-websocket`).
3. Optional in `~/.config/ha-kit.env`: `HA_BACKUP_DEST=/path/on/another/disk`, `HA_BACKUP_KEEP=14`.
4. Cron after your HA backup time: `45 3 * * * $HOME/ha-community-kit/02-ha-backup-offbox/pull-ha-backup.sh`
5. Run it once by hand and check the log says `copied <slug>`.
