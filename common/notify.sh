#!/usr/bin/env bash
# usage: notify.sh "title" "message"
# Sends a time-sensitive push to your phone through Home Assistant. If that fails (HA down, network down),
# it falls back to email (email-alert.py), which does not depend on HA. Never fails its caller.
. "$(dirname "$0")/load-config.sh"
title=${1:-server}; msg=${2:-}
body=$(jq -n --arg t "$title" --arg m "$msg" \
  '{title: $t, message: $m, data: {push: {"interruption-level": "time-sensitive"}}}')
code=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer $(ha_token)" -H 'Content-Type: application/json' \
  -d "$body" "$HA_URL/api/services/notify/${HA_NOTIFY#notify.}")
if [ "$code" != 200 ]; then
  if python3 "$KIT_DIR/common/email-alert.py" "$title" "$msg (Phone push failed: http $code. Sent by email instead.)"; then
    via=email; else via=NOTHING; fi
  echo "$(date '+%F %T') push failed (http $code), fallback=$via: $title | $msg" >> "$STATE_DIR/notify-failed.log"
fi
exit 0
