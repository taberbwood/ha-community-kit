#!/usr/bin/env bash
# Cron: */10 * * * *   Server watches Home Assistant.
# 3 failed checks in a row (~30 min) -> ONE email (HA's own push is the thing that is down, so it cannot be
# used), then one more email when HA answers again. State: $STATE_DIR/ha-watch.state = "<fails> <alerted>".
. "$(dirname "$0")/../common/load-config.sh"
ST="$STATE_DIR/ha-watch.state"; LOG="$STATE_DIR/ha-watch.log"
{ read -r fails alerted < "$ST"; } 2>/dev/null || { fails=0; alerted=0; }
code=$(curl -s -m 20 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $(ha_token)" "$HA_URL/api/")
if [ "$code" = 200 ]; then
  if [ "$alerted" = 1 ]; then
    python3 "$KIT_DIR/common/email-alert.py" "Home Assistant is reachable again" "Phone alerts work again." \
      && echo "$(date '+%F %T') back; recovery email sent" >> "$LOG"
  fi
  echo "0 0" > "$ST"; exit 0
fi
fails=$((fails + 1)); echo "$(date '+%F %T') HA check failed (http $code), $fails in a row" >> "$LOG"
if [ "$fails" -ge 3 ] && [ "$alerted" != 1 ]; then
  if python3 "$KIT_DIR/common/email-alert.py" "Home Assistant unreachable" \
     "The server has not reached Home Assistant for about 30 minutes (last result: http $code). While HA is down, no phone alerts can be sent."; then
    alerted=1; echo "$(date '+%F %T') alert email sent" >> "$LOG"
  else
    echo "$(date '+%F %T') alert email FAILED" >> "$LOG"
  fi
fi
echo "$fails $alerted" > "$ST"
