# Reptile tank alerts with adjustable limits and a "sensor went silent" alarm

Built for a ball python with two cheap Bluetooth thermometer/hygrometers (one on the warm side, one on
the cool side) that Home Assistant already reads. Works for any enclosure: aquariums, incubators,
seed starting, a wine fridge.

## What it does

| Alert | When |
|---|---|
| Temperature | A side stays outside its limits for 15 minutes |
| Humidity | Outside its limits for 30 minutes |
| Battery | A sensor drops below 20% |
| **Sensor silent** | A sensor has not reported for 2 hours |

The last one matters most. A Bluetooth sensor with a dead battery, or one knocked out of range, raises no
error: it simply stops updating. Without this alert, your temperature alerts look fine while watching
nothing.

## Limits you can change without editing anything

Create Number helpers (Settings > Devices & services > Helpers > Number), mode "input field", step 1:

| Helper | Suggested start (ball python) |
|---|---|
| `input_number.tank_warm_min_temp` / `tank_warm_max_temp` | 82 / 96 °F |
| `input_number.tank_cool_min_temp` / `tank_cool_max_temp` | 72 / 86 °F |
| `input_number.tank_humidity_min` / `tank_humidity_max` | 40 / 80 % |

These are deliberately **wider** than common care-sheet targets (roughly 88 to 92 °F warm, 75 to 80 °F cool,
50 to 70 % humidity): they are "act now" limits, so the phone only buzzes for real problems. Check your
species' needs with a reptile vet or a care guide you trust. Put the helpers on a dashboard as tile cards
with the "numeric input" feature to adjust them from your phone.

## Setup

1. Make sure HA already shows your sensors (for example via the Govee BLE or other Bluetooth integration).
2. Create the six helpers above.
3. Paste each automation from `tank-automations.yaml` (they are separated by `---`), replacing entity ids
   and the notify service. Duplicate the temperature and humidity ones for the second sensor.
4. Send yourself a test: in Developer tools > Actions, run your notify service once.

## Design notes

- `for:` durations stop a door opening or a misting from paging you.
- The `from_state` condition skips the false trigger when a sensor comes back from "unavailable" after
  an HA restart.
- No "back to normal" message on purpose: a short blip that never triggered an alert would otherwise
  produce an all-clear for a problem you never heard about.
