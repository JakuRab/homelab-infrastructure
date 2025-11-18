› Please take a look into homelabbing folder, familiarise yourself with homelabbing/homelab.md and then help me with my current situation:
  my Clockworkcity server machine routinely disappears from tailscale network. Please help me fix that. Secondly help me return to a state
  when I can ssh into it with tailscale magic dns using name@machine from my current pc. Yesterday I was able to ssh using lan ip, even
  tailscale ip, but not tailscale name. Right now I have the same experience


• I’m going to scan the homelabbing folder and open homelabbing/homelab.md to align with your setup before proposing fixes.

• Explored
  └ List ls -la
    List homelabbing
    Search rg --files homelabbing
    Read homelab.md

• Updated Plan
  └ Set up a focused plan: review docs, stabilize Tailscale on the server, fix MagicDNS on the client, and add a resilient SSH fallback.
    ✔ Review homelab docs
    □ Stabilize Tailscale on server
    □ Fix MagicDNS on client
    □ Add resilient SSH fallback

─ Worked for 2m 17s ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• I’ve read your homelab notes. I’ll tailor Tailscale fixes to clockworkcity (Ubuntu, 192.168.1.10, Tailscale 100.98.21.87, MagicDNS suffix
  tail7d1f88.ts.net).

  What’s Likely Happening

  - Disappearing from Tailscale: tailscaled not staying healthy (service restarts, key/ephemeral auth, or networking flaps).
  - MagicDNS failure: your current PC isn’t using Tailscale’s DNS/search domain, so short hostnames (e.g., ssh name@clockworkcity) don’t
    resolve even though IPs work.

  Server: Stabilize Tailscale (clockworkcity)

  - Verify service health and persistence:
      - sudo systemctl is-active tailscaled && systemctl is-enabled tailscaled
      - If not active/enabled: sudo systemctl enable --now tailscaled
  - Check for obvious causes in logs (restarts, key expiry, auth issues, OOM):
      - journalctl -u tailscaled --since "24h" -e
      - Look for “key expired”, “ephemeral”, “re-auth”, “panic”, “killed”, “restarting”.
  - Ensure it’s not ephemeral and key is valid:
      - tailscale status --self (confirm “Ephemeral: false” and not expired)
      - If ephemeral/expired: sudo tailscale logout && sudo tailscale up (interactive) or reauth with a non‑ephemeral auth key.
  - Keep it reachable:
      - Confirm shields are down: sudo tailscale set --shields-up=false
      - Update to latest: sudo apt-get update && sudo apt-get install tailscale
  - Optional hardening (if logs show restarts): set aggressive restart policy
      - sudo systemctl edit tailscaled then add:
          - [Service]
          - Restart=always
          - RestartSec=5s
      - sudo systemctl daemon-reload && sudo systemctl restart tailscaled

  Client: Fix MagicDNS resolution (your current PC)

  - First, test FQDN via Tailscale’s resolver:
      - nslookup clockworkcity.tail7d1f88.ts.net 100.100.100.100
  SSH with MagicDNS (short name)

      - Before: ssh -v name@clockworkcity (you’ll see DNS failures)
      - After: the verbose output should show it resolving via the tail7d1f88.ts.net search domain.

  Good Stopgap (ssh alias)

  - Add an alias so SSH works even if search domains break:
      - Edit ~/.ssh/config on your PC and add:
          - Host clockworkcity
          -   HostName clockworkcity.tail7d1f88.ts.net
          -   User name
      - Then ssh clockworkcity will always work via the FQDN.

  If the server still “disappears”

  - Share snippets from journalctl -u tailscaled --since "24h" -e showing any “key expired”, “ephemeral”, or repeated restart messages.
  - Also run on the server: tailscale status --self and tailscale version.
  - If OOM or NIC issues are suspected: journalctl -k --since "24h" | rg -i 'oom|link is down|link up|eth|enp4s0'.

  Would you confirm the OS of your current PC (Linux/macOS/Windows)? If Linux, please paste:

  - tailscale status --self
  - resolvectl status | sed -n '/tailscale0/,+15p'
  - nslookup clockworkcity.tail7d1f88.ts.net 100.100.100.100

  I can then pinpoint whether it’s a DNS policy issue on the client or a server auth/lifecycle issue and adjust the next steps.


› Regarding stabilisation:

  sudo systemctl is-active tailscaled && systemctl is-enabled tailscaled
  active & enabled

  journalctl -u tailscaled --since "24h" -e
  Failed to parse timestamp: 24h

  tailscale status --self no information regarding "ephemeral" status - clockworkcity is: idle; offers exit node

  tailscale is just freshly updated minutes ago, server has been restarted as well

  Regarding Magic DNS

  netcheck does not give any information regarding magic dns

  ping: clockworkcity.tail7d1f88.ts.net: Name or service not known


• Reviewing search domain settings (1m 11s • esc to interrupt)

• Reviewing search domain settings (1m 14s • esc to interrupt)

• Updated Plan
  └ Server tailscaled is active/enabled and updated; shifting focus to
    client MagicDNS resolution which is currently failing.
    ✔ Review homelab docs
    ✔ Stabilize Tailscale on server
    □ Fix MagicDNS on client
    □ Add resilient SSH fallback

─ Worked for 1m 40s ──────────────────────────────────────────────────

• Thanks — that helps. Two tracks: fix client MagicDNS, and
  double‑check server logs with correct syntax.

  Server Checks

  - Correct journalctl syntax:
      - sudo journalctl -u tailscaled --since=-24h
      - If needed, filter: sudo journalctl -u tailscaled --since=-24h
        | rg -i 'error|fail|panic|oom|expired|auth|exit'
  - Time sync sanity (clock drift can cause flakiness):
      - timedatectl status (expect “System clock synchronized: yes”).
        If not, sudo systemctl enable --now systemd-timesyncd or
        ensure chrony/ntp is healthy.

  Given tailscaled is active/enabled and freshly updated, the
  “disappears from Tailscale” may be transient network/clock. If logs
  are clean and time is synced, we’ll keep an eye on it.

  Client: Fix MagicDNS

  - Get the exact FQDN suffix (it may not be tail7d1f88.ts.net):
      - tailscale status and find the full name printed for
        clockworkcity (e.g., clockworkcity.<suffix>.ts.net).
  - Test MagicDNS resolver directly:
      - nslookup clockworkcity.<suffix>.ts.net 100.100.100.100
      - If this works, MagicDNS is fine server‑side; your client isn’t
        using Tailscale DNS.
  - Reapply Tailscale DNS on the client:
      - sudo tailscale down && sudo tailscale up --accept-dns=true
  - Verify DNS routing on Linux (systemd‑resolved):
      - resolvectl status | sed -n '/tailscale0/,+15p'
      - Expect Current DNS Server: 100.100.100.100 and a domain like
        ~<suffix>.ts.net.
  - If tailscale0 isn’t present in resolved, your system may not be
    using resolved:
      - Check: ls -l /etc/resolv.conf
          - If not a symlink to /run/systemd/resolve/stub-resolv.conf,
            consider:
              - sudo mv /etc/resolv.conf /etc/resolv.conf.backup
              - sudo ln -s /run/systemd/resolve/stub-resolv.conf /
                etc/resolv.conf
              - sudo systemctl restart systemd-resolved
              - Then rerun: sudo tailscale up --accept-dns=true
  - If FQDN works but short name doesn’t, add the tailnet search
    domain:
      - Replace <suffix>.ts.net with your actual suffix:
          - sudo resolvectl domain tailscale0 <suffix>.ts.net
            ~<suffix>.ts.net
      - Verify getent hosts clockworkcity and then ssh
        name@clockworkcity.

  SSH Now

  - Once FQDN resolves, ssh name@clockworkcity will work if the search
    domain is applied. As a quick workaround:
      - ~/.ssh/config:
          - Host clockworkcity
          -   HostName clockworkcity.<suffix>.ts.net
          -   User name

  If any step fails, please paste:

  - From client:
      - tailscale status | sed -n '1,120p'
      - nslookup clockworkcity.<suffix>.ts.net 100.100.100.100
      - ls -l /etc/resolv.conf
      - resolvectl status | sed -n '/tailscale0/,+15p'
  - From server:
      - sudo journalctl -u tailscaled --since=-24h | tail -n 200
      - timedatectl status | sed -n '1,12p'

  With those, I can pinpoint whether it’s a DNS plumbing issue on your
  PC or a tailnet/MagicDNS config issue.



› journal is massive with over 5k records, but here are the latest
  that seem to repeat:

  Oct 30 16:37:08 clockworkcity tailscaled[841]: dns: OScfg: {}
  Oct 30 16:37:08 clockworkcity tailscaled[841]: wgengine: set DNS
  config again after major link change
  Oct 30 16:37:08 clockworkcity tailscaled[841]: router:
  portUpdate(port=41641, network=udp6)
  Oct 30 16:37:08 clockworkcity tailscaled[841]: magicsock: 1 active
  derp conns: derp-22=cr15m0s,wr17s
  Oct 30 16:37:08 clockworkcity tailscaled[841]: router:
  portUpdate(port=41641, network=udp4)
  Oct 30 16:37:08 clockworkcity tailscaled[841]: magicsock: disco:
  node [+YZI4] d:dd387ab0026ec527 now using 192.168.1.111:41641
  mtu=1360 tx=edaa17882e4b
  Oct 30 16:37:08 clockworkcity tailscaled[841]: post-rebind ping of
  DERP region 22 okay
  Oct 30 16:37:11 clockworkcity tailscaled[841]: monitor:
  RTM_DELROUTE: src=, dst=fe80::/64, gw=, outif=82, table=254
  Oct 30 16:37:11 clockworkcity tailscaled[841]: monitor:
  RTM_DELROUTE: src=, dst=fe80::f4fb:cbff:fe9e:8892/128, gw=,
  outif=82, table=255
  Oct 30 16:37:11 clockworkcity tailscaled[841]: monitor:
  RTM_DELROUTE: src=, dst=ff00::/8, gw=, outif=82, table=255
  Oct 30 16:37:11 clockworkcity tailscaled[841]: monitor:
  [unexpected] network state changed, but stringification didn't:
  interfaces.State{defaultRoute=enp4s0 ifs={br-0c9a7293c017:
  [172.22.0.1/16 llu6] br-1829bc5f109b:[172.19.0.1/16] br-
  2cf4323640b6:[172.18.0.1/16 llu6] br-9138d1bc820b:>
  Oct 30 16:37:11 clockworkcity tailscaled[841]: monitor:
  [unexpected] old: {"InterfaceIPs":{"br-0c9a7293c017":
  ["172.22.0.1/16","fe80::30f8:cfff:fed7:3a61/64"],"br-1829bc5f109b":
  ["172.19.0.1/16"],"br-2cf4323640b6":
  ["172.18.0.1/16","fe80::2ce2:b8ff:fe62:d20c/64"],"br-9138d1bc820b":
  ["172>
  Oct 30 16:37:11 clockworkcity tailscaled[841]: monitor:
  [unexpected] new: {"InterfaceIPs":{"br-0c9a7293c017":
  ["172.22.0.1/16","fe80::30f8:cfff:fed7:3a61/64"],"br-1829bc5f109b":
  ["172.19.0.1/16"],"br-2cf4323640b6":
  ["172.18.0.1/16","fe80::2ce2:b8ff:fe62:d20c/64"],"br-9138d1bc820b":
  ["172>
  Oct 30 16:37:11 clockworkcity tailscaled[841]: LinkChange: major,
  rebinding. New state: interfaces.State{defaultRoute=enp4s0 ifs={br-
  0c9a7293c017:[172.22.0.1/16 llu6] br-1829bc5f109b:[172.19.0.1/16]
  br-2cf4323640b6:[172.18.0.1/16 llu6] br-9138d1bc820b:[172.21.0.1/16
  llu6] br-d03155dc>
  Oct 30 16:37:11 clockworkcity tailscaled[841]: dns: Set:
  {DefaultResolvers:[] Routes:{} SearchDomains:[] Hosts:6}
  Oct 30 16:37:11 clockworkcity tailscaled[841]: dns: Resolvercfg:
  {Routes:{} Hosts:6 LocalDomains:[]}


• Good data points. Your server looks healthy; the repeating logs are
  from Docker bridge churn causing Tailscale to rebind, but DERP pings
  are OK. The MagicDNS problem is on the client side.

  What the logs mean

  - “LinkChange: major, rebinding” and “magicsock … DERP OK” →
    clockworkcity is online; Docker creates many interfaces and
    triggers harmless rebinding.
  - “dns: OScfg: {} … SearchDomains: []” → tailscaled isn’t setting OS
    DNS on the server (fine for a server; not related to your client’s
    failure).

  Validate Connectivity vs. DNS (from your current PC)

  - Overlay connectivity (bypasses OS DNS): tailscale ping
    clockworkcity
      - If this succeeds, only name resolution is broken on the
        client.
  - Find the exact tailnet suffix: tailscale status (top lines show
    MagicDNS domain) or:
      - tailscale status --json | jq -r .MagicDNSSuffix
  - Resolver test (replace <suffix>): nslookup
    clockworkcity.<suffix>.ts.net 100.100.100.100
      - If this works, MagicDNS is fine; your PC isn’t sending queries
        to Tailscale’s DNS.

  Fix MagicDNS on your current PC (Linux)

  - Reapply Tailscale DNS: sudo tailscale down && sudo tailscale up
    --accept-dns=true
  - Check systemd‑resolved is in use:
      - ls -l /etc/resolv.conf (ideally symlink to /run/systemd/
        resolve/stub-resolv.conf)
      - If not, switch: sudo mv /etc/resolv.conf /etc/
        resolv.conf.backup && sudo ln -s /run/systemd/resolve/
        stub-resolv.conf /etc/resolv.conf && sudo systemctl restart

  - Once the search domain is applied, ssh name@clockworkcity works.
  - Safe alias regardless of search domain:
      - ~/.ssh/config:
          - Host clockworkcity
          -   HostName clockworkcity.<suffix>.ts.net
          -   User name

  If any step fails, please paste from your PC:

  - tailscale status | sed -n '1,60p'
  - tailscale status --json | jq -r .MagicDNSSuffix
  - nslookup clockworkcity.<suffix>.ts.net 100.100.100.100
  - ls -l /etc/resolv.conf
  - resolvectl status | sed -n '/tailscale0/,+15p'

  From the server (to finish the “disappears” angle):

  - sudo journalctl -u tailscaled --since=-24h | rg -i 'error|fail|
    expired|auth|iptables|nft' | tail -n 50
  - timedatectl status | sed -n '1,12p'
