# Homelab Secrets Repository

**⚠️ PRIVATE REPOSITORY - DO NOT MAKE PUBLIC ⚠️**

This repository contains actual environment variables and secrets for the homelab infrastructure.

## Repository Structure

```
.secrets-templates/
├── README.md                    # This file
├── stacks/                      # Secrets organized by stack
│   ├── caddy/
│   │   └── .env                # Cloudflare API token
│   ├── net_monitor/
│   │   └── .env                # Grafana credentials
│   ├── n8n/
│   │   └── .env                # n8n configuration
│   └── ...
└── deployment-guide.md          # How to deploy secrets
```

## Usage on Server

### Manual Deployment

1. Clone this repository to the server:
   ```bash
   git clone https://github.com/YOUR_USERNAME/homelab-secrets.git ~/homelab-secrets
   ```

2. Link secrets to stack directories:
   ```bash
   # For each stack:
   ln -s ~/homelab-secrets/stacks/STACK_NAME/.env ~/homelab/stacks/STACK_NAME/.env
   ```

### With Portainer

When deploying stacks via Portainer Git integration:

1. **Option A: Environment Variables in UI**
   - Copy contents of `.env` file
   - Paste into Portainer's "Environment variables" section when creating stack

2. **Option B: Use Docker Secrets** (Recommended)
   - Create Docker secrets from .env files
   - Reference them in compose files
   - More secure than environment variables

## Security Notes

- **Never commit unencrypted secrets to public repos**
- Keep this repository **PRIVATE**
- Consider using `git-crypt` or SOPS for encryption at rest
- Rotate secrets regularly
- Use strong, unique passwords for each service

## Backup Strategy

- This repo should be backed up separately
- Consider encrypted offline backup
- Store critical recovery keys (like n8n encryption key) in password manager

## Secrets Inventory

| Stack | Secret Type | Description |
|-------|-------------|-------------|
| caddy | API Token | Cloudflare DNS-01 ACME |
| net_monitor | Password | Grafana admin credentials |
| n8n | Multiple | Host config, encryption key |
| ... | ... | ... |
