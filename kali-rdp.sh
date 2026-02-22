#!/bin/bash

# --- Color Palette ---
ACCENT='\033[1;36m'  # Cyan
SUCCESS='\033[1;32m' # Green
DANGER='\033[1;31m'  # Red
INFO='\033[1;34m'    # Blue
WARN='\033[1;33m'    # Yellow
BOLD='\033[1m'
NC='\033[0m'         # No Color

get_status() {
  if [ "$(docker ps -aq -f name=kali-rdp)" ]; then
    if [ "$(docker ps -q -f name=kali-rdp)" ]; then
      STATUS="${SUCCESS}● ON (Running)${NC}"
      IS_RUNNING=true
      IS_INSTALLED=true
    else
      STATUS="${DANGER}○ OFF (Stopped)${NC}"
      IS_RUNNING=false
      IS_INSTALLED=true
    fi
  else
    STATUS="${BOLD}◌ NOT INSTALLED${NC}"
    IS_RUNNING=false
    IS_INSTALLED=false
  fi
}

get_ips() {
  PUBLIC_IP=$(curl -s ifconfig.me || echo "Error")
  LOCAL_IP=$(hostname -I | awk '{print $1}')
  [ -z "$PUBLIC_IP" ] && PUBLIC_IP="Not Found"
  [ -z "$LOCAL_IP" ] && LOCAL_IP="Not Found"
}

# --- Menu Functions ---

install_kali() {
  if [ "$IS_INSTALLED" = true ]; then
    echo -e "\n${WARN}⚠️  Kali RDP is already installed!${NC}"; sleep 2
    return
  fi
  echo -e "\n${INFO}🚀 Installing Kali RDP...${NC}"
  docker run -d \
    --name kali-rdp \
    -p 3389:3389 \
    --privileged \
    nobitaa/kali-rdp:latest
  echo -e "${SUCCESS}✅ Installed Successfully!${NC}"
  sleep 2
}

turn_on() {
  if [ "$IS_INSTALLED" = false ]; then
    echo -e "\n${DANGER}❌ Not installed! Choice [1] first.${NC}"; sleep 2
  else
    echo -e "\n${SUCCESS}▶️  Starting Kali RDP...${NC}"
    docker start kali-rdp >/dev/null
    sleep 2
  fi
}

turn_off() {
  echo -e "\n${DANGER}⏹️  Stopping Kali RDP...${NC}"
  docker stop kali-rdp >/dev/null
  sleep 2
}

restart_kali() {
  echo -e "\n${INFO}🔄 Restarting Kali RDP...${NC}"
  docker restart kali-rdp >/dev/null
  sleep 2
}

uninstall_all() {
  echo -e "\n${DANGER}🗑  Removing Container...${NC}"
  docker stop kali-rdp &>/dev/null
  docker rm kali-rdp &>/dev/null
  echo -e "${DANGER}🔥 Deleting Docker Image...${NC}"
  docker rmi nobitaa/kali-rdp:latest &>/dev/null
  echo -e "${SUCCESS}✨ System Cleaned.${NC}"
  sleep 2
}

login_info() {
  clear
  get_ips
  echo -e "${ACCENT}┌──────────────────────────────────────────┐${NC}"
  echo -e "${ACCENT}│${NC}  ${BOLD}🔑 KALI RDP ACCESS${NC}                   ${ACCENT}│${NC}"
  echo -e "${ACCENT}├──────────────────────────────────────────┤${NC}"
  echo -e "   ${BOLD}User:${NC} ${SUCCESS}kali${NC}"
  echo -e "   ${BOLD}Pass:${NC} ${SUCCESS}kali123${NC}"
  echo -e "   ${BOLD}Port:${NC} 3389"
  echo -e " "
  echo -e "   ${INFO}Public IP:${NC} $PUBLIC_IP"
  echo -e "   ${INFO}Local IP:${NC}  $LOCAL_IP"
  echo -e "${ACCENT}└──────────────────────────────────────────┘${NC}"
  echo -e "${WARN}Connect using Remote Desktop Connection (RDP)${NC}"
  read -p " Press [Enter] to return..."
}

# --- Main Interface ---
while true; do
  clear
  get_status
  get_ips

  echo -e "${ACCENT}╔══════════════════════════════════════════╗${NC}"
  echo -e "${ACCENT}║${NC}         ${BOLD}💀 KALI RDP MANAGER 💀${NC}           ${ACCENT}║${NC}"
  echo -e "${ACCENT}╚══════════════════════════════════════════╝${NC}"
  echo -e "  ${BOLD}STATUS:${NC}    $STATUS"
  echo -e "  ${BOLD}LOCAL IP:${NC}  $LOCAL_IP"
  echo -e "${ACCENT}────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}[1]${NC} ${SUCCESS}Install${NC}"
  echo -e "  ${BOLD}[2]${NC} ${INFO}Turn ON${NC}"
  echo -e "  ${BOLD}[3]${NC} ${WARN}Turn OFF${NC}"
  echo -e "  ${BOLD}[4]${NC} ${ACCENT}Restart${NC}"
  echo -e "  ${BOLD}[5]${NC} ${DANGER}Uninstall (Clear All)${NC}"
  echo -e "  ${BOLD}[6]${NC} Login Info"
  echo -e "  ${BOLD}[0]${NC} Exit"
  echo ""
  echo -ne "  ${ACCENT}Selection ➜ ${NC}"
  read choice

  case $choice in
    1) install_kali ;;
    2) turn_on ;;
    3) turn_off ;;
    4) restart_kali ;;
    5) uninstall_all ;;
    6) login_info ;;
    0) echo -e "${INFO}Bye! 👋${NC}"; exit ;;
    *) echo -e "${DANGER}❌ Invalid Option${NC}"; sleep 1 ;;
  esac
done
