#!/usr/bin/env bash
# Cron: 45 3 * * *  (after HA's own automatic backup; adjust to your backup time)
# Copies Home Assistant's newest backup OFF the HA box onto this server (a different machine and disk).
#
# THE TRAP this script exists for: Supervisor reports every backup made by HA's built-in automatic backup
# feature as type "partial", even a complete one (core + database + all add-ons + all folders). A script
# that selects type=="full" finds only your old manual backups, copies nothing new, and logs nothing wrong.
# So select on content (does it contain Home Assistant itself?), not on type.
. "$(dirname "$0")/../common/load-config.sh"
DEST=${HA_BACKUP_DEST:-/srv/ha-backups}; KEEP=${HA_BACKUP_KEEP:-14}
LOG="$STATE_DIR/ha-backup.log"
alert() { echo "$(date '+%F %T') ALERT $*" >> "$LOG"; "$KIT_DIR/common/notify.sh" "HA backup copy failed" "$*"; exit 1; }

mkdir -p "$DEST" && chmod 700 "$DEST" || alert "cannot create $DEST"
latest=$(python3 "$KIT_DIR/common/ha-ws.py" '{"type":"supervisor/api","endpoint":"/backups","method":"get"}' \
  | jq -r '.result.backups | map(select(.content.homeassistant == true)) | sort_by(.date) | last | "\(.slug) \(.date[0:10])"') \
  || alert "could not list HA backups"
slug=${latest%% *}; day=${latest##* }
[ -n "$slug" ] && [ "$slug" != null ] || alert "HA has no backup that contains Home Assistant"
[ "$day" \> "$(date -d '-2 days' +%F)" ] || alert "newest HA backup is from $day: HA's automatic backup is not running"
f="$DEST/ha-$day-$slug.tar"
if ls "$DEST"/ha-*-"$slug".tar >/dev/null 2>&1; then echo "$(date '+%F %T') already have $slug ($day)" >> "$LOG"; exit 0; fi
code=$(curl -s -m 1800 -o "$f.part" -w '%{http_code}' -H "Authorization: Bearer $(ha_token)" \
  "$HA_URL/api/hassio/backups/$slug/download")
# Note: this download endpoint DOES work with a normal token, unlike most /api/hassio/* REST paths.
[ "$code" = 200 ] && tar -tf "$f.part" | grep -q homeassistant.tar.gz \
  || { rm -f "$f.part"; alert "download of $slug failed (http $code) or archive unreadable"; }
mv "$f.part" "$f"; chmod 600 "$f"
ls -1t "$DEST"/ha-*.tar | tail -n +$((KEEP + 1)) | xargs -r rm -f
echo "$(date '+%F %T') copied $slug ($day) $(stat -c %s "$f") bytes; $(ls "$DEST"/ha-*.tar | wc -l) kept" >> "$LOG"
