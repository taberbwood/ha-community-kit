# Home Assistant "can't reach" your Tailscale services? It may only be DNS

## The symptom

You run Home Assistant OS with the Tailscale add-on, and services on other machines in your tailnet
(say `https://myserver.your-tailnet.ts.net:8080`) fail from HA integrations: "cannot connect", name not
found. You try from the SSH add-on: `*.ts.net` names do not resolve and `100.x.y.z` addresses do not
answer either. It looks like HA has no route into the tailnet at all.

## What was actually wrong

Two separate things, and the second hides the first:

1. **The SSH / Terminal add-on is a bad place to test.** It runs in its own network namespace, so what
   it can or cannot reach says nothing about HA core. Test from HA core instead (below).
2. **HA core could reach the tailnet IPs fine. Only the names failed.** HA does not use the host's DNS
   settings: it asks the Supervisor's own DNS service, which forwards to your router. Your router has
   never heard of `*.ts.net`, so every tailnet name fails, even with the add-on's `accept_dns` on.

## How to test from HA core itself

Add a temporary **Ping (ICMP)** integration (Settings > Devices & services > Add integration > Ping)
once for the tailnet IP of the target machine and once for its `*.ts.net` name. The ping runs from HA
core. If the IP is "connected" and the name is not, it is DNS. Delete both afterwards.

## The fix

Point the Supervisor's DNS at Tailscale's resolver, `100.100.100.100` (MagicDNS). It answers tailnet
names and passes everything else on. Your router stays in the list as a fallback.

We applied it through the Supervisor API over HA's websocket (`common/ha-ws.py`):

```
python3 common/ha-ws.py '{"type":"supervisor/api","endpoint":"/dns/options","method":"post","data":{"servers":["dns://100.100.100.100"]}}'
python3 common/ha-ws.py '{"type":"supervisor/api","endpoint":"/dns/info","method":"get"}'
# servers: ["dns://100.100.100.100"], locals: ["dns://<your router>"]
```

To undo, post `{"servers": []}` the same way.

The `ha` CLI in the Terminal / SSH add-on should do the same (`ha dns options --servers dns://100.100.100.100`,
then `ha dns info`), but we did not run it that way ourselves, so check `ha dns --help` first.

## Check afterwards

- The ping integration for the `*.ts.net` name turns "connected".
- An internet name still resolves (add a ping for `one.one.one.one`).
- **Phone notifications still work.** They need internet DNS, so send yourself a test push. If anything
  fails, undo at once.

## Notes

- Keep the add-on's `userspace_networking` off (kernel networking), so HA core gets a real route into
  the tailnet.
- Keep `accept_routes` **off** if another tailnet machine advertises your own LAN as a subnet route.
  Accepting it on a box that sits inside that LAN can send your LAN traffic through the tailnet.
- Not tested here: whether lookups fall back cleanly to the router when the Tailscale add-on is stopped.
  Try it while you have keyboard access to the HA machine.
