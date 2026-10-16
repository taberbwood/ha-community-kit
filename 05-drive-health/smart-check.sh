#!/usr/bin/env bash
# Cron: 0 6 * * *   Drive health early warning, quiet unless something gets WORSE.
# For every disk: SMART overall health plus counters 5 (Reallocated), 197 (Current_Pending),
# 198 (Offline_Uncorrectable), 187 (Reported_Uncorrect) and the drive's ATA error-log count.
# First run saves a baseline; afterwards it pushes only when health fails or a counter RISES, so an old
# drive with known damage is reported once, and any NEW damage is reported again.
# Needs: smartmontools, sudo rights for smartctl (or run as root).
. "$(dirname "$0")/../common/load-config.sh"
BASE="$STATE_DIR/smart.baseline"; LOG="$STATE_DIR/smart.log"; N=${N:-$KIT_DIR/common/notify.sh}
touch "$BASE"; new=$(mktemp); msgs=()
for d in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
  out=$(sudo smartctl -H -A "/dev/$d" 2>/dev/null); [ -z "$out" ] && continue
  info=$(sudo smartctl -i "/dev/$d")
  model=$(awk -F: '/Device Model|Model Number/{gsub(/^ +/,"",$2); print $2; exit}' <<< "$info")
  serial=$(awk -F: '/Serial Number/{gsub(/ /,"",$2); print $2; exit}' <<< "$info")
  [ -z "$serial" ] && continue
  health=$(grep -E -o "PASSED|FAILED" <<< "$out" | head -1)
  val() { awk -v id="$1" '$1==id{print $10; exit}' <<< "$out"; }
  r=$(val 5); p=$(val 197); u=$(val 198); e=$(val 187); r=${r:-0}; p=${p:-0}; u=${u:-0}; e=${e:-0}
  a=$(sudo smartctl -l error "/dev/$d" 2>/dev/null | awk '/Error Count:/{print $4; exit}'); a=${a:-0}
  echo "$serial $r $p $u $e $a" >> "$new"
  echo "$(date '+%F %T') $d $model $serial health=${health:-?} realloc=$r pending=$p uncorrectable=$u reported_uncorrect=$e ata_errors=$a" >> "$LOG"
  [ "$health" = FAILED ] && msgs+=("/dev/$d ($model) SMART overall health FAILED.")
  if read -r _ br bp bu be ba < <(grep "^$serial " "$BASE"); then :; else br=$r; bp=$p; bu=$u; be=$e; ba=$a; fi
  be=${be:-$e}; ba=${ba:-$a}
  for x in "realloc $r $br" "pending $p $bp" "uncorrectable $u $bu" "reported-uncorrectable $e $be" "logged-error $a $ba"; do
    set -- $x; [ "$2" -gt "$3" ] 2>/dev/null && msgs+=("/dev/$d ($model, $serial): $1 count rose $3 -> $2.")
  done
done
mv "$new" "$BASE"   # today's values become the baseline, so the same damage is reported once
if [ ${#msgs[@]} -gt 0 ]; then "$N" "Drive health warning" "$(printf '%s ' "${msgs[@]}")Details: $LOG"; fi
exit 0
