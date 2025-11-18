#!/bin/bash
# Initial setup script for pushing repositories to GitHub
# Run this after creating repositories on GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Homelab Infrastructure - Initial Git Setup ===${NC}\n"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "stacks" ]; then
    echo -e "${RED}Error: Run this script from the aiTools directory!${NC}"
    exit 1
fi

# Get GitHub username
read -p "Enter your GitHub username: " GITHUB_USER
if [ -z "$GITHUB_USER" ]; then
    echo -e "${RED}Error: GitHub username cannot be empty${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Step 1: Committing main repository...${NC}"
git add .
git commit -m "Initial commit: GitOps homelab infrastructure

- Restructured configs → stacks/
- Created .env.template files for all services
- Moved secrets to separate directory structure
- Comprehensive documentation (deployment, disaster recovery, Portainer setup)
- README files for each stack
- Ready for Portainer Git integration

Services included:
- Caddy (reverse proxy with Cloudflare DNS plugin)
- n8n (workflow automation)
- Home Assistant
- Monitoring stack (Prometheus + Grafana + Blackbox)
- Portainer
- Tailscale hardening configs"

echo -e "${GREEN}✓ Committed main repository${NC}\n"

echo -e "${YELLOW}Step 2: Setting up remote for main repository...${NC}"
MAIN_REPO="https://github.com/${GITHUB_USER}/homelab-infrastructure.git"
git remote add origin "$MAIN_REPO" 2>/dev/null || git remote set-url origin "$MAIN_REPO"
echo -e "${GREEN}✓ Remote configured: $MAIN_REPO${NC}\n"

echo -e "${YELLOW}Step 3: Pushing main repository...${NC}"
echo -e "${YELLOW}(You may be prompted for GitHub credentials)${NC}"
git push -u origin main

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Main repository pushed successfully!${NC}\n"
else
    echo -e "${RED}✗ Failed to push main repository${NC}"
    echo -e "${YELLOW}Make sure you've created the repository on GitHub:${NC}"
    echo -e "  https://github.com/${GITHUB_USER}/homelab-infrastructure"
    exit 1
fi

echo -e "${YELLOW}Step 4: Setting up secrets repository...${NC}"
cd .secrets-templates

# Initialize if not already done
if [ ! -d ".git" ]; then
    git init
    git branch -m main
fi

git add .
git commit -m "Initial secrets for homelab infrastructure

PRIVATE REPOSITORY - Contains production credentials

Secrets included:
- Cloudflare API token for Caddy DNS-01 ACME
- Grafana admin credentials
- Service-specific environment variables" 2>/dev/null || echo "Already committed"

SECRETS_REPO="https://github.com/${GITHUB_USER}/homelab-secrets.git"
git remote add origin "$SECRETS_REPO" 2>/dev/null || git remote set-url origin "$SECRETS_REPO"

echo -e "${GREEN}✓ Secrets repository configured${NC}\n"

echo -e "${YELLOW}Step 5: Pushing secrets repository...${NC}"
echo -e "${RED}⚠️  WARNING: Make sure homelab-secrets is PRIVATE on GitHub!${NC}"
read -p "Press Enter to continue or Ctrl+C to abort..."

git push -u origin main

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Secrets repository pushed successfully!${NC}\n"
else
    echo -e "${RED}✗ Failed to push secrets repository${NC}"
    echo -e "${YELLOW}Make sure you've created a PRIVATE repository on GitHub:${NC}"
    echo -e "  https://github.com/${GITHUB_USER}/homelab-secrets"
    exit 1
fi

cd ..

echo -e "\n${GREEN}=== Setup Complete! ===${NC}\n"
echo -e "Main repository: ${GREEN}$MAIN_REPO${NC}"
echo -e "Secrets repository: ${GREEN}$SECRETS_REPO${NC} ${RED}(PRIVATE!)${NC}\n"

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify repositories are accessible on GitHub"
echo "2. On your server, clone secrets repo:"
echo "   ${GREEN}git clone $SECRETS_REPO ~/homelab-secrets${NC}"
echo "3. Deploy n8n via Portainer (see docs/n8n-migration-test.md)"
echo "4. Configure webhook for auto-deployment"
echo ""
echo "See ${GREEN}docs/deployment.md${NC} for detailed instructions."
