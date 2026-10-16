# Vaultwarden backups you have actually proven, plus a safe restore drill

A backup you have never restored from is a guess. This is how to turn it into a fact without touching
your live vault.

## 1. Back up properly

`vaultwarden-backup.sh` makes one dated copy per night with `sqlite3 .backup` (safe while the server is
running), checks it with `PRAGMA integrity_check`, adds `rsa_key.pem`, compresses it, and keeps 14.
Set `VW_DATA`, `VW_BACKUP_DEST`, `VW_KEEP` at the top or in the environment. Put the destination on a
**different physical disk** from the vault if you can: a backup on the same disk dies with it.

## 2. Check the copy matches the live vault

```
d=$(mktemp -d); gunzip -c /srv/backups/vaultwarden/$(date +%F)/db.sqlite3.gz > $d/db.sqlite3
Q="select (select count(*) from users),(select count(*) from ciphers),(select count(*) from folders),(select max(updated_at) from ciphers);"
sqlite3 $d/db.sqlite3 "PRAGMA integrity_check;"
sqlite3 $d/db.sqlite3 "$Q"
sudo sqlite3 "file:/srv/vaultwarden/db.sqlite3?mode=ro" "$Q"     # live, read-only
```

Counts and the newest change should match. (Matching counts prove the copy is complete, not that it
decrypts. Step 3 proves that.)

## 3. The real proof: log in to a throwaway copy

1. Copy the backup into a scratch folder (`mkdir` with mode 700; it holds your encrypted vault).
2. Start a second Vaultwarden from the **same image** as your live one, on that copy, bound to localhost
   only, with sign-ups off:
   ```
   docker run -d --rm --name vw-drill -v /scratch/drill:/data -p 127.0.0.1:18080:80 \
     -e SIGNUPS_ALLOWED=false -e DOMAIN=https://<your-host>:18080 vaultwarden/server:<same tag>
   ```
3. **The web vault refuses plain http** ("Insecure URL not allowed"). Put HTTPS in front of it. With
   Tailscale: `tailscale serve --bg --https=18080 http://127.0.0.1:18080`, then browse to
   `https://<your-host>:18080`. It stays reachable only inside your tailnet.
4. Log in with your normal account and master password. Check your item and folder counts, open a couple
   of entries. Do not let a browser extension save anything from that page.
5. Tear it all down: `tailscale serve --https=18080 off`, `docker rm -f vw-drill`, delete the scratch copy.

A trap in step 2's checks: Vaultwarden's prelogin endpoint returns the same answer for an email that does
not exist (on purpose, so nobody can probe for accounts). It cannot prove your account loaded. Only the
login can.

## 4. While you are in there

- **Close sign-ups** once your household has accounts (`SIGNUPS_ALLOWED=false`). New people join by
  invite from `/admin` and still choose their own master password.
- **Lock the backup folder** to your admin user (`700`). If it sits on a disk that is also shared over
  SMB (a media drive, say), anyone who can browse that share could otherwise read the files.
