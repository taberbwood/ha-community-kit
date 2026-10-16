# ha-community-kit

Six small, tested pieces for a self-hosted home: a Linux server next to Home Assistant OS, joined by
Tailscale. Each folder stands alone and explains a problem we actually hit, how we found it, and the fix.

| # | Folder | What it solves |
|---|---|---|
| 1 | `01-two-way-watchdog` | Alerts that still reach you when Home Assistant itself is down (server and HA watch each other; email fallback) |
| 2 | `02-ha-backup-offbox` | Copying HA backups to another machine, and the trap: automatic backups are typed `partial`, so "copy the newest full backup" silently copies nothing |
| 3 | `03-ha-tailscale-dns` | HA "can't reach" tailnet services when only DNS is broken, and why the SSH add-on misleads you |
| 4 | `04-tank-alerts` | Reptile or aquarium alerts with limits you adjust from a dashboard, plus a "sensor went silent" alarm |
| 5 | `05-drive-health` | SMART alerts that stay quiet until a drive gets worse, and watch the counters that actually caught a failing drive |
| 6 | `06-vaultwarden-backup-drill` | Dated, consistent Vaultwarden backups and a safe restore drill that proves you can log in |

## Shared setup (folders 1, 2, 5)

1. Copy this folder to the server, e.g. `~/ha-community-kit`.
2. Install `curl`, `jq`, `python3` (and `python3-websocket` for folder 2, `smartmontools` for folder 5).
3. `cp common/config.example.env ~/.config/ha-kit.env`, fill it in, `chmod 600 ~/.config/ha-kit.env`.
4. Put your HA long-lived token and SMTP app password in the files the config names, `chmod 600` each.
5. Read the folder's README, run the script once by hand, then add its cron line.

Folders 3, 4 and 6 are mostly instructions plus YAML or a standalone script.

## Principles we followed

- **Nothing is trusted until it has run once and been tested on purpose.** Each README has a test that
  makes the alert fire.
- **One alert per problem, plus one when it is over.** No spam, so you keep reading them.
- **The alert path must not depend on the thing it watches.**
- **No secrets in scripts.** Tokens and passwords live in `chmod 600` files and are never printed.

## Requirements and assumptions

The original versions run on Ubuntu 22.04 next to Home Assistant OS (Core 2026.10) with the Tailscale
add-on, and each was tested by forcing its alert to fire. **The copies here are generalized** (paths, names
and services replaced with placeholders and a shared config file) and were syntax-checked, not re-run in
this exact form. Change the placeholders to yours, run each script once by hand, and do the test in its
README before you rely on it. Use at your own risk; read a script before you run it.

## License

MIT, see `LICENSE`.
