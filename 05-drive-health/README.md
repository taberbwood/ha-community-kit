# Drive health alerts that only speak up when something gets worse

## The problem

Most SMART checks either alert on every run for an old drive with known, stable damage (so you learn
to ignore them), or only watch the "big three" counters: 5 (reallocated), 197 (pending) and 198
(offline uncorrectable).

We had a 5-year-old drive with real read errors that showed **0 / 0 / 0 on all three** and "PASSED". Its
damage lived elsewhere: counter **187 (Reported_Uncorrect) = 5** and **7 entries in the drive's own ATA
error log**. A check on the big three would never have noticed it getting worse.

## What this does

- Reads every disk's overall health and counters 5, 197, 198, 187 plus the ATA error-log count.
- The first run records them as a baseline. Later runs push to your phone (via `common/notify.sh`,
  email fallback) only if health fails or **any counter rises**.
- The new values become the baseline, so each new piece of damage is reported once, not daily.

## Setup

1. `apt install smartmontools`. The script calls `sudo smartctl`, so the user running it needs that
   right (or run it from root's crontab).
2. Common setup from `01-two-way-watchdog/README.md` steps 1 to 3.
3. Run it once by hand to create the baseline, and read `$STATE_DIR/smart.log`.
4. Cron: `0 6 * * * $HOME/ha-community-kit/05-drive-health/smart-check.sh`

## Test it without waiting for a drive to fail

Edit `$STATE_DIR/smart.baseline` and lower one number for one drive, then run
`N=echo ./smart-check.sh`. It prints the warning instead of pushing. Run it again: silent.

## Limits

- USB enclosures often hide SMART data; those drives are skipped quietly.
- NVMe drives report different fields; this script reads the ATA-style table, so NVMe coverage is basic.
- SMART warns about some failures, not all. It is no substitute for a second copy of your data.
