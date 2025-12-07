#!/bin/bash
# ========================================================
# Media Stack Directory Setup Script
# ========================================================
# Run this script on narsis to create the complete
# directory structure for all media stack services.
#
# Usage:
#   chmod +x setup-directories.sh
#   ./setup-directories.sh
# ========================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="/mnt/nvme/services/media"
PUID=$(id -u)
PGID=$(id -g)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Media Stack Directory Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Base directory: $BASE_DIR"
echo "Owner: $(whoami) (PUID=$PUID, PGID=$PGID)"
echo ""

# Check if running on narsis
if [ ! -d "/mnt/nvme" ]; then
    echo -e "${RED}ERROR: /mnt/nvme not found!${NC}"
    echo "This script should be run on narsis (192.168.1.11)"
    exit 1
fi

# Function to create directory with proper ownership
create_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}Creating:${NC} $dir"
        sudo mkdir -p "$dir"
    else
        echo -e "${GREEN}Exists:${NC} $dir"
    fi
}

echo -e "${YELLOW}Creating directory structure...${NC}"
echo ""

# ========================================
# Config Directories (for container configs)
# ========================================
echo -e "${GREEN}[1/4] Config directories${NC}"
create_dir "$BASE_DIR/config"

# Download stack
create_dir "$BASE_DIR/config/gluetun"
create_dir "$BASE_DIR/config/qbittorrent"

# Arr stack
create_dir "$BASE_DIR/config/prowlarr"
create_dir "$BASE_DIR/config/radarr"
create_dir "$BASE_DIR/config/sonarr"
create_dir "$BASE_DIR/config/lidarr"

# Streaming stack
create_dir "$BASE_DIR/config/jellyfin"
create_dir "$BASE_DIR/config/jellyfin/cache"
create_dir "$BASE_DIR/config/jellyfin/transcodes"
create_dir "$BASE_DIR/config/navidrome"

echo ""

# ========================================
# Download Directories
# ========================================
echo -e "${GREEN}[2/4] Download directories${NC}"
create_dir "$BASE_DIR/downloads"
create_dir "$BASE_DIR/downloads/incomplete"
create_dir "$BASE_DIR/downloads/complete"
create_dir "$BASE_DIR/downloads/complete/movies"
create_dir "$BASE_DIR/downloads/complete/tv"
create_dir "$BASE_DIR/downloads/complete/music"
create_dir "$BASE_DIR/downloads/torrents"

echo ""

# ========================================
# Media Library Directories
# ========================================
echo -e "${GREEN}[3/4] Media library directories${NC}"
create_dir "$BASE_DIR/media"
create_dir "$BASE_DIR/media/movies"
create_dir "$BASE_DIR/media/tv"
create_dir "$BASE_DIR/media/music"

echo ""

# ========================================
# Set Ownership
# ========================================
echo -e "${GREEN}[4/4] Setting ownership${NC}"
echo -e "${YELLOW}Setting owner to $PUID:$PGID for all directories...${NC}"
sudo chown -R $PUID:$PGID "$BASE_DIR"

echo -e "${YELLOW}Setting permissions (755 for directories)...${NC}"
sudo find "$BASE_DIR" -type d -exec chmod 755 {} \;

echo -e "${YELLOW}Setting permissions (644 for files, if any exist)...${NC}"
sudo find "$BASE_DIR" -type f -exec chmod 644 {} \;

echo ""

# ========================================
# Verification
# ========================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo "Directory structure:"
tree -L 3 -d "$BASE_DIR" 2>/dev/null || ls -laR "$BASE_DIR"

echo ""
echo "Disk usage:"
du -sh "$BASE_DIR"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete! ✅${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy media-download stack in Portainer"
echo "  2. Deploy media-arr stack in Portainer"
echo "  3. Deploy media-streaming stack in Portainer"
echo "  4. Configure Caddy reverse proxy"
echo "  5. Add DNS rewrites in AdGuard Home"
echo ""
echo "See README.md files in each stack directory for detailed instructions."
echo ""
