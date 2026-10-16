#!/usr/bin/env bash
# Cron: 0 3 * * *   Consistent, dated Vaultwarden backups that keep history.
#
# Replaces the common "rsync --delete the data folder every night" approach, which has two problems:
#  1. No history. If the vault is ever emptied or damaged (a container starting on an unmounted disk will
#     happily create a brand-new EMPTY vault), the next night's mirror copies the damage over your only
#     good backup.
#  2. Copying a live SQLite file can catch it half-written.
# This uses sqlite3's own .backup (safe while Vaultwarden runs), checks integrity, keeps N dated copies.
set -euo pipefail
VW=${VW_DATA:-/srv/vaultwarden}            # the folder mounted as /data in the container
DEST=${VW_BACKUP_DEST:-/srv/backups/vaultwarden}
KEEP=${VW_KEEP:-14}                        # ~1 MB per night compressed for a typical personal vault
D="$DEST/$(date +%F)"

sudo mkdir -p "$D"
sudo sqlite3 "$VW/db.sqlite3" ".backup '$D/db.sqlite3'"
[ "$(sudo sqlite3 "$D/db.sqlite3" 'PRAGMA integrity_check;')" = ok ]   # fail loudly, never keep a bad copy
sudo cp -p "$VW/rsa_key.pem" "$D/"                                     # needed to restore logins
for x in attachments sends; do [ -d "$VW/$x" ] && sudo cp -a "$VW/$x" "$D/"; done
sudo gzip -f "$D/db.sqlite3"
sudo chown -R "$(id -u):$(id -g)" "$DEST"; chmod 700 "$DEST" "$D"; chmod 600 "$D"/*.gz "$D"/rsa_key.pem
ls -1d "$DEST"/20??-??-?? | head -n -"$KEEP" | xargs -r rm -rf
echo "$(date '+%F %T') vaultwarden backup OK -> $D"
