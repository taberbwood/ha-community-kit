#!/usr/bin/env python3
"""usage: email-alert.py "subject" "body"

Sends an email through any SMTP account (STARTTLS). This is the alert channel that does not depend on
Home Assistant. Settings come from ~/.config/ha-kit.env (or $HA_KIT_ENV). The password is read from
SMTP_PASS_FILE and never printed. Exit 0 on success, 1 on failure.
"""
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage


def load_env(path):
    env = {}
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = os.path.expanduser(os.path.expandvars(v.strip()))
    return env


cfg = load_env(os.environ.get("HA_KIT_ENV", os.path.expanduser("~/.config/ha-kit.env")))
subject, body = (sys.argv[1:3] + ["", ""])[:2]
try:
    password = open(cfg["SMTP_PASS_FILE"]).read().strip()
    msg = EmailMessage()
    msg["From"] = cfg["SMTP_USER"]
    msg["To"] = cfg["ALERT_TO"]
    msg["Subject"] = subject
    msg.set_content(body + "\n\n(sent by ha-community-kit email-alert.py)")
    with smtplib.SMTP(cfg["SMTP_HOST"], int(cfg.get("SMTP_PORT", 587)), timeout=30) as s:
        s.starttls(context=ssl.create_default_context())
        s.login(cfg["SMTP_USER"], password)
        s.send_message(msg)
except Exception as e:  # report the type only: never echo settings or secrets
    print(f"email failed: {type(e).__name__}", file=sys.stderr)
    sys.exit(1)
