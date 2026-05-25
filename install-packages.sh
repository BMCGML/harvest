#!/bin/bash

# ============================================================
# BRGM_Schueler — Package Install Script
# Raspberry Pi 4B+ (Built-in WiFi, no adapter needed)
# Run this first to install everything
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Run with sudo: sudo bash $0${NC}"
    exit 1
fi

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   BRGM_Schueler — Package Install        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ------------------------------------------------------------
echo -e "${YELLOW}[1/5] Updating package lists...${NC}"
sudo apt update -qq

# ------------------------------------------------------------
echo -e "${YELLOW}[2/5] Installing hostapd-wpe (evil twin AP + RADIUS)...${NC}"
sudo apt install -y hostapd-wpe

# ------------------------------------------------------------
echo -e "${YELLOW}[3/5] Installing cracking tools...${NC}"
sudo apt install -y asleap hashcat

# ------------------------------------------------------------
echo -e "${YELLOW}[4/5] Installing dnsmasq (DHCP server)...${NC}"
sudo apt install -y dnsmasq

# ------------------------------------------------------------
echo -e "${YELLOW}[5/5] Verifying installations...${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   INSTALL COMPLETE                   ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"

PKGS=("hostapd-wpe" "asleap" "hashcat" "dnsmasq")
ALL_GOOD=true

for pkg in "${PKGS[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        echo -e "${GREEN}║  ✅ $pkg${NC}"
    else
        echo -e "${RED}║  ❌ $pkg — NOT INSTALLED${NC}"
        ALL_GOOD=false
    fi
done

echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"

if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}║  All packages installed successfully.              ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Next step: run the attack script                   ║${NC}"
    echo -e "${GREEN}║  The attack script will be created separately       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}║  Some packages failed. Check errors above.        ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
