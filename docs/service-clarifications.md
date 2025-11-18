# Service Clarifications

Findings from investigating unclear services in the homelab.

---

## 1. Marreta (`ram.rabalski.eu`)

### ✅ IDENTIFIED

**What it is:**
- **Marreta** is a paywall bypass and reading accessibility tool
- Removes access barriers and visual distractions from web pages
- Self-hosted alternative to services like 12ft.io

**Official Repository:**
- Main project: https://github.com/manualdousuario/marreta
- Your deployment uses: `ghcr.io/tiagocoutinh0/marreta:latest` (fork)

**Purpose:**
- Break through paywalls on news sites and articles
- Remove distracting elements (ads, popups, cookie banners)
- Improve reading experience
- Privacy-focused (self-hosted, no third-party tracking)

**How it works:**
1. User visits `https://ram.rabalski.eu`
2. Enters URL of article behind paywall
3. Marreta fetches and cleans the content
4. Returns readable version without barriers

**Features:**
- Multi-language support (Portuguese, English, Spanish, German, Russian)
- Browser extension available for easier use
- Works with many major news sites

**Current Deployment:**
```yaml
# From homelab.md
services:
  marreta:
    image: ghcr.io/tiagocoutinh0/marreta:latest
    container_name: marreta
    restart: unless-stopped
    networks: [caddy_net]
```

**Caddyfile Entry:**
```caddy
ram.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://marreta:80
}
```

**Assessment:**
- ✅ Legitimate tool (reading accessibility, not piracy)
- ✅ Simple deployment (single container, no data)
- ✅ Low resource usage
- ✅ Privacy-focused

**Migration Priority:** LOW (nice to have, not critical)

### Stack Files to Create

- [ ] `stacks/marreta/docker-compose.yml`
- [ ] `stacks/marreta/.env.template` (if any config needed)
- [ ] `stacks/marreta/README.md`

**Migration Notes:**
- No persistent data (stateless service)
- No secrets required
- Very simple migration
- Good candidate for Phase 4 (low priority)

---

## 2. Cloudflare DDNS

### ❌ NOT FOUND - Service Does Not Exist

**Finding:**
- No Cloudflare DDNS service currently deployed
- No compose files found
- No container references
- No Caddyfile entries
- **Conclusion: This service was never deployed or was removed**

**Why it might have been considered:**
- Dynamic IP addresses need DNS updates
- Cloudflare API can update A/AAAA records

**Current DNS Management:**
- **Caddy** handles all Cloudflare interaction via DNS-01 ACME
- Uses `CF_API_TOKEN` for Let's Encrypt certificate validation
- Creates/updates TXT records for ACME challenges

**Does Caddy update A/AAAA records?**
- **No**, Caddy only manages TXT records for ACME
- A/AAAA records must be updated separately if IP changes

**Do you need DDNS?**

**Check if your IP is static:**
```bash
# On server, check current public IP
curl -s https://api.ipify.org
# Or
curl -s https://ifconfig.me

# Check again tomorrow - if it changes, you need DDNS
```

**Options if you need DDNS:**

1. **Check with ISP:**
   - Many ISPs offer static IPs (sometimes free for business)
   - Simpler than DDNS

2. **Use Cloudflare DDNS service:**
   - Lightweight container: `oznu/cloudflare-ddns`
   - Updates A/AAAA records when IP changes
   - Simple to deploy

3. **Use Tailscale for access:**
   - You already have Tailscale configured
   - Access via Tailscale IP (never changes)
   - No DDNS needed for remote access

**Current Status:**
- Public DNS records point to: `31.178.228.90` (per homelab.md)
- Check if this IP is static
- If static, no DDNS needed ✅
- If dynamic, deploy DDNS service

**Recommendation:**

**Test for 1 week:**
```bash
# Create a simple monitoring script
echo "$(date): $(curl -s https://api.ipify.org)" >> ~/ip-log.txt

# Add to crontab (run every 6 hours)
0 */6 * * * echo "$(date): $(curl -s https://api.ipify.org)" >> ~/ip-log.txt

# After 1 week, check:
cat ~/ip-log.txt | sort -u
# If only one IP = static (no DDNS needed)
# If multiple IPs = dynamic (deploy DDNS)
```

**If DDNS is needed, create:**
- [ ] `stacks/cloudflare-ddns/docker-compose.yml`
- [ ] `stacks/cloudflare-ddns/.env.template`
- [ ] `stacks/cloudflare-ddns/README.md`

**If DDNS is NOT needed:**
- [x] Remove from service inventory
- [x] Document that IP is static
- [x] No migration required

---

## Summary & Action Items

### Marreta
- ✅ **Identified**: Paywall bypass / reading accessibility tool
- ✅ **Currently deployed**: `ram.rabalski.eu`
- ✅ **Migration needed**: Yes, Phase 4 (low priority)
- ✅ **Docker image**: `ghcr.io/tiagocoutinh0/marreta:latest`
- ✅ **Stateless**: No persistent data
- ✅ **Simple migration**: Single container, no secrets

### Cloudflare DDNS
- ❌ **Not found**: Service does not exist in current deployment
- ⏳ **Need to determine**: Is your public IP static or dynamic?
- ⏳ **Test for 1 week**: Monitor IP changes
- ⏳ **Decision pending**: Deploy DDNS only if IP changes

### Updated Service Count

**Total Services: 16** (not 17)
- 15 deployed services
- 1 potential service (DDNS - if needed)

**Revised Inventory:**
- Critical: 6 (unchanged)
- Monitoring & Tools: 4 (unchanged)
- Productivity: 5 (Marreta identified)
- Infrastructure: 4 (unchanged - Tailscale)
- Evaluate: 1 (DDNS - pending IP test)

---

## Questions Answered ✅

### 1. What is Marreta?
**Answer:** Paywall bypass and reading accessibility tool. Removes paywalls, ads, and distractions from web articles. Self-hosted for privacy.

### 2. Is Marreta still used?
**Answer:** Based on:
- Active in Caddyfile
- Listed in service catalog
- Monitored by Prometheus
**Conclusion:** YES, still in use

### 3. Is Cloudflare DDNS deployed?
**Answer:** NO - service does not exist in current infrastructure

### 4. Do we need Cloudflare DDNS?
**Answer:** UNKNOWN - need to test if public IP is static or dynamic

---

## Next Steps

### Immediate
- [x] Identify Marreta
- [x] Confirm DDNS status
- [ ] Update service inventory with findings
- [ ] Test public IP stability

### For Marreta Migration
1. Create stack directory
2. Create docker-compose.yml
3. Create .env.template (if config needed)
4. Create README.md
5. Migrate in Phase 4 (low priority)

### For Cloudflare DDNS Decision
1. Monitor public IP for 1 week
2. If static → Remove from inventory, document
3. If dynamic → Create stack, deploy DDNS service

---

**Date:** 2025-11-18
**Status:** Clarifications complete, pending IP stability test
