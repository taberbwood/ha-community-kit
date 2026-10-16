#!/usr/bin/env python3
"""usage: ha-ws.py '<json command>' ['<json command>' ...]

Minimal Home Assistant websocket client. Prints each result as one JSON line.
Needed for Supervisor calls (backups, add-ons, DNS): with a normal long-lived token, the REST path
/api/hassio/* answers 401, but the websocket "supervisor/api" command works.
Requires: pip install websocket-client  (Debian/Ubuntu: apt install python3-websocket)
"""
import json
import os
import sys

import websocket


def load_env(path):
    env = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = os.path.expanduser(os.path.expandvars(v.strip()))
    return env


cfg = load_env(os.environ.get("HA_KIT_ENV", os.path.expanduser("~/.config/ha-kit.env")))
token = open(cfg["HA_TOKEN_FILE"]).read().strip()
url = cfg["HA_URL"].replace("https://", "wss://").replace("http://", "ws://") + "/api/websocket"
ws = websocket.create_connection(url, timeout=900)
ws.recv()
ws.send(json.dumps({"type": "auth", "access_token": token}))
if json.loads(ws.recv()).get("type") != "auth_ok":
    sys.exit("auth failed")
for i, raw in enumerate(sys.argv[1:], 1):
    cmd = json.loads(raw)
    cmd["id"] = i
    ws.send(json.dumps(cmd))
    while True:
        reply = json.loads(ws.recv())
        if reply.get("id") == i and reply.get("type") == "result":
            print(json.dumps(reply))
            break
