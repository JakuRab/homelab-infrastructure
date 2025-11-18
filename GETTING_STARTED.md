# Getting Started - GitOps Homelab

Quick start guide for your newly GitOps-enabled homelab infrastructure.

## What's Been Done

Your homelab infrastructure has been restructured for professional Git-based management:

### ✅ Repository Structure
- **Organized stacks**: All services moved from `homelabbing/configs/` to `stacks/`
- **Git initialized**: Ready to push to GitHub
- **Secrets separated**: Production credentials moved to separate structure
- **Documentation**: Comprehensive guides for deployment, disaster recovery, and Portainer setup

### ✅ Files Created
- `.gitignore` - Prevents committing secrets
- `README.md` - Repository overview
- `docs/deployment.md` - Complete deployment guide
- `docs/portainer-setup.md` - Portainer Git integration guide
- `docs/disaster-recovery.md` - Rebuild procedures
- `docs/n8n-migration-test.md` - Test migration guide
- `scripts/initial-setup.sh` - Helper script for GitHub push
- `.env.template` files - For all services
- Stack READMEs - Service-specific documentation

### ✅ Services Ready for Migration
- Caddy (reverse proxy)
- n8n (workflow automation) - **Test case**
- Home Assistant
- Monitoring stack (Prometheus + Grafana)
- Portainer
- Tailscale configs

## Quick Start (3 Steps)

### 1. Create GitHub Repositories

**Two repositories needed:**

1. **Main infrastructure** (public or private, your choice):
   - Go to https://github.com/new
   - Name: `homelab-infrastructure`
   - Visibility: Your preference
   - **Don't** initialize with README
   - Create

2. **Secrets** (MUST be private):
   - Go to https://github.com/new
   - Name: `homelab-secrets`
   - Visibility: **Private**
   - **Don't** initialize with README
   - Create

### 2. Push to GitHub

**Easy way** (using helper script):
```bash
cd /home/kuba/aiTools
./scripts/initial-setup.sh
```

**Manual way**:
```bash
# Main repo
cd /home/kuba/aiTools
git add .
git commit -m "Initial commit: GitOps homelab infrastructure"
git remote add origin https://github.com/YOUR_USERNAME/homelab-infrastructure.git
git push -u origin main

# Secrets repo
cd .secrets-templates
git init
git branch -m main
git add .
git commit -m "Initial secrets for homelab"
git remote add origin https://github.com/YOUR_USERNAME/homelab-secrets.git
git push -u origin main
```

### 3. Test with n8n Migration

Follow the detailed guide: `docs/n8n-migration-test.md`

**Quick version:**

1. **On server:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/homelab-secrets.git ~/homelab-secrets
   docker stop n8n  # If running
   docker rm n8n    # If exists
   ```

2. **In Portainer UI:**
   - Stacks → Add Stack → Repository
   - URL: `https://github.com/YOUR_USERNAME/homelab-infrastructure`
   - Reference: `refs/heads/main`
   - Path: `stacks/n8n/docker-compose.yml`
   - Add environment variables from `~/homelab-secrets/stacks/n8n/.env`
   - Deploy

3. **Configure webhook** for auto-deploy on push

## Your Workflow Going Forward

### Making Changes

```bash
# Edit configuration locally
cd /home/kuba/aiTools
vim stacks/SERVICE_NAME/docker-compose.yml

# Commit and push
git add stacks/SERVICE_NAME/
git commit -m "Update SERVICE_NAME configuration"
git push

# Portainer auto-deploys (if webhook configured)
# Or manually: Portainer → Stack → Pull and redeploy
```

### Adding New Service

1. Create directory: `stacks/NEW_SERVICE/`
2. Add `docker-compose.yml` with `caddy_net` network
3. Create `.env.template` for required variables
4. Add actual secrets to `.secrets-templates/stacks/NEW_SERVICE/.env`
5. Create `README.md` documenting the service
6. Commit and push both repos
7. Deploy via Portainer Git integration

### Updating Secrets

```bash
# Edit secrets
cd /home/kuba/aiTools/.secrets-templates
vim stacks/SERVICE/.env

# Commit and push
git add stacks/SERVICE/.env
git commit -m "Update SERVICE secrets"
git push

# On server: pull and redeploy
ssh user@clockworkcity
cd ~/homelab-secrets
git pull
# Then redeploy stack in Portainer
```

## Benefits of This Setup

### 🔐 Security
- **Secrets separated**: Never committed to main repo
- **Version controlled**: Track all changes
- **Easy rotation**: Update secrets, push, redeploy

### 🚀 Reliability
- **Disaster recovery**: Rebuild entire homelab from Git
- **Rollback**: Revert bad changes with `git revert`
- **Audit trail**: See who changed what and when

### ⚡ Efficiency
- **Auto-deploy**: Push to Git → Portainer redeploys automatically
- **No SSH needed**: Manage from anywhere with Git push
- **Consistent**: Same config across test/staging/prod

### 📚 Documentation
- **Self-documenting**: Code is documentation
- **Searchable**: Find configs with `git grep`
- **Shareable**: Help others with similar setups

## Key Files Reference

| File | Purpose |
|------|---------|
| `README.md` | Repository overview, quick reference |
| `docs/deployment.md` | How to deploy services |
| `docs/portainer-setup.md` | Portainer Git integration |
| `docs/disaster-recovery.md` | Complete rebuild procedures |
| `docs/n8n-migration-test.md` | First migration test plan |
| `stacks/*/docker-compose.yml` | Service definitions |
| `stacks/*/.env.template` | Required environment variables |
| `stacks/*/README.md` | Service-specific docs |
| `.secrets-templates/` | Actual production secrets |

## Troubleshooting

### Can't push to GitHub
- Verify repository exists on GitHub
- Check remote: `git remote -v`
- May need personal access token instead of password
- GitHub Settings → Developer settings → PAT

### Portainer shows "Limited" control
- Stack was deployed outside Portainer
- Solution: `docker compose down`, redeploy via Portainer
- See `docs/portainer-setup.md` for details

### Webhook not triggering
- Verify webhook URL is correct
- Check GitHub webhook deliveries (Settings → Webhooks)
- Ensure Portainer is accessible from internet (or use polling)

### Service can't access secrets
- Check environment variables in Portainer UI
- Verify secrets repo was cloned to server
- Confirm variable names match compose file

## Next Steps

1. ✅ **Push to GitHub** (use `./scripts/initial-setup.sh`)
2. ⏳ **Migrate n8n** (test case - see `docs/n8n-migration-test.md`)
3. ⏳ **Configure webhooks** for auto-deployment
4. ⏳ **Migrate remaining services** one by one
5. ⏳ **Set up backups** for volumes and secrets
6. ⏳ **Configure monitoring** for failed deployments

## Support

- **Documentation**: Check `docs/` directory
- **Architecture**: See `homelabbing/homelab.md`
- **Issues**: Use GitHub Issues on your repo
- **Claude Code**: Ask for help with CLAUDE.md context

---

**Congratulations!** 🎉

You now have a professional, Git-based infrastructure management system for your homelab. This is the same approach used by companies managing production Kubernetes clusters with GitOps tools like ArgoCD and Flux.

Your homelab is now:
- ✅ Version controlled
- ✅ Disaster-recoverable
- ✅ Auto-deployable
- ✅ Professionally documented

**Happy homelabbing!** 🏠🔧
