#!/bin/bash
# =====================================================
# Ubuntu Server - Sistem Məlumatları Skripti
# İstifadə: sudo bash sistem_melumat.sh
# =====================================================

# Rəng kodları
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

line() {
    echo -e "${CYAN}--------------------------------------------------${NC}"
}

header() {
    echo ""
    line
    echo -e "${YELLOW}$1${NC}"
    line
}

# ---------------------------------------------------
header "1. ÜMUMİ SİSTEM MƏLUMATI"
echo -e "${GREEN}Hostname:${NC} $(hostname)"
echo -e "${GREEN}OS:${NC} $(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)"
echo -e "${GREEN}Kernel:${NC} $(uname -r)"
echo -e "${GREEN}Arxitektura:${NC} $(uname -m)"
echo -e "${GREEN}Uptime:${NC} $(uptime -p 2>/dev/null || uptime)"

# ---------------------------------------------------
header "2. TARİX VƏ SAAT"
echo -e "${GREEN}Sistem saatı:${NC} $(date)"
echo -e "${GREEN}Timezone:${NC} $(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3, $4, $5}')"
if command -v timedatectl >/dev/null 2>&1; then
    NTP_STATUS=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
    echo -e "${GREEN}NTP sinxronizasiyası:${NC} ${NTP_STATUS:-Naməlum}"
fi

# ---------------------------------------------------
header "3. ŞƏBƏKƏ / IP MƏLUMATLARI"

# Əsas fiziki interfeysi tapmağa çalışırıq (loopback, docker, bridge, veth istisna)
MAIN_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev '^(lo|docker|br-|veth|virbr)' | head -n1)

if [ -z "$MAIN_IF" ]; then
    echo "Əsas şəbəkə interfeysi tapılmadı."
else
    IP_ADDR=$(ip -4 addr show "$MAIN_IF" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    echo -e "${GREEN}İnterfeys:${NC} $MAIN_IF"
    echo -e "${GREEN}IP ünvanı:${NC} $IP_ADDR"
    echo -e "${GREEN}Gateway:${NC} $GATEWAY"

    # Statik / Dinamik yoxlanışı
    IP_METHOD="Naməlum"
    if command -v nmcli >/dev/null 2>&1; then
        CONN_NAME=$(nmcli -t -f DEVICE,NAME connection show --active | grep "^$MAIN_IF:" | cut -d: -f2)
        if [ -n "$CONN_NAME" ]; then
            METHOD=$(nmcli -g ipv4.method connection show "$CONN_NAME" 2>/dev/null)
            case "$METHOD" in
                manual) IP_METHOD="STATİK (manual - NetworkManager)" ;;
                auto)   IP_METHOD="DİNAMİK (DHCP - NetworkManager)" ;;
                *)      IP_METHOD="Naməlum (NetworkManager: $METHOD)" ;;
            esac
        fi
    fi
    # Netplan yaml-larda əlavə yoxlama (fallback)
    if [ "$IP_METHOD" = "Naməlum" ] && [ -d /etc/netplan ]; then
        if grep -q "dhcp4:\s*true" /etc/netplan/*.yaml 2>/dev/null; then
            IP_METHOD="DİNAMİK (DHCP - netplan)"
        elif grep -qE "addresses:" /etc/netplan/*.yaml 2>/dev/null; then
            IP_METHOD="STATİK (netplan)"
        fi
    fi
    echo -e "${GREEN}IP tipi:${NC} $IP_METHOD"
fi

echo -e "${GREEN}DNS serverləri:${NC}"
resolvectl status 2>/dev/null | grep "DNS Server" | sed 's/^/  /' || cat /etc/resolv.conf | grep nameserver | sed 's/^/  /'

# ---------------------------------------------------
header "4. DOCKER MƏLUMATLARI"
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}Docker quraşdırılıb.${NC} Versiya: $(docker --version)"
    echo ""
    echo -e "${GREEN}İşləyən konteynerlər və portlar:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    echo ""
    RUNNING_COUNT=$(docker ps -q | wc -l)
    TOTAL_COUNT=$(docker ps -aq | wc -l)
    echo -e "${GREEN}İşləyən:${NC} $RUNNING_COUNT   ${GREEN}Cəmi (dayandırılmış daxil):${NC} $TOTAL_COUNT"
else
    echo "Docker quraşdırılmayıb."
fi

# ---------------------------------------------------
header "5. FIREWALL STATUSU"
if command -v ufw >/dev/null 2>&1; then
    echo -e "${GREEN}UFW:${NC}"
    ufw status verbose 2>/dev/null | sed 's/^/  /'
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo -e "${GREEN}firewalld:${NC} $(firewall-cmd --state 2>/dev/null)"
else
    echo "UFW/firewalld tapılmadı. iptables qaydalarına baxılır:"
    iptables -L -n 2>/dev/null | head -n 15 | sed 's/^/  /'
fi

# ---------------------------------------------------
header "6. SİSTEM İSTİFADƏÇİLƏRİ"
echo -e "${GREEN}Login edə bilən (real) istifadəçilər:${NC}"
awk -F: '$3>=1000 && $1!="nobody" {print "  - " $1 " (UID:" $3 ", Shell:" $7 ")"}' /etc/passwd

echo ""
echo -e "${GREEN}Hazırda sistemə daxil olanlar:${NC}"
who

echo ""
line
echo -e "${YELLOW}Hesabat tamamlandı.${NC}"
line
