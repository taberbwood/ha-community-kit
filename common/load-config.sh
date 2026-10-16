# Sourced by every shell script in the kit. Reads ~/.config/ha-kit.env (or $HA_KIT_ENV).
HA_KIT_ENV=${HA_KIT_ENV:-$HOME/.config/ha-kit.env}
if [ ! -r "$HA_KIT_ENV" ]; then
  echo "ha-kit: config not found at $HA_KIT_ENV (copy common/config.example.env there)" >&2
  exit 2
fi
set -a; . "$HA_KIT_ENV"; set +a
mkdir -p "$STATE_DIR"
ha_token() { tr -d '[:space:]' < "$HA_TOKEN_FILE"; }
