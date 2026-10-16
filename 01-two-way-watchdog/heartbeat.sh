#!/usr/bin/env bash
# Cron: */10 * * * *   Server -> Home Assistant "I'm alive".
# Sets input_datetime.server_heartbeat to now. The HA automation in heartbeat-automation.yaml pushes to
# your phone if this stops landing for 30 minutes. Silence covers every failure: server down, cron dead,
# network path down, token revoked.
. "$(dirname "$0")/../common/load-config.sh"
curl -s -m 20 -o /dev/null -X POST \
  -H "Authorization: Bearer $(ha_token)" -H 'Content-Type: application/json' \
  -d "{\"entity_id\": \"input_datetime.server_heartbeat\", \"timestamp\": $(date +%s)}" \
  "$HA_URL/api/services/input_datetime/set_datetime"
exit 0
