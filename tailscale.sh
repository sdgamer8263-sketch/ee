#!/bin/bash

# ==================================================
#  SERVER CONTROL CENTER | TAILSCALE ONLY (DOCKER)
# ==================================================

# --- 1. COLORS & STYLING ---
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; M="\e[35m"; W="\e[97m"
BG_BLUE="\e[44;97m"; BG_G="\e[42;97m"; BG_R="\e[41;97m"; GREY="\e[90m"
RESET="\e[0m"; BOLD="\e[1m"; DIM="\e[2m"

# --- 2. UTILITY ---
pause() { echo -e "\n${GREY}  Press Enter to return to menu...${RESET}"; read -r _; }

get_ts_ip() {
    if docker ps --format '{{.Names}}' | grep -q "^tailscale$"; then
        local ip=$(docker exec tailscale tailscale ip 2>/dev/null | head -n1)
        echo "${ip:-Connecting...}"
    else
        echo "Disconnected"
    fi
}

# --- 3. HEADER UI ---
draw_header() {
    clear
    local user=$(whoami)
    local host=$(hostname)
    local load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)

    # Status Pills
    local doc_status="${BG_R} OFF ${RESET}"; [[ $(command -v docker) ]] && doc_status="${BG_G} OK ${RESET}"
    
    local ts_container_check=$(docker ps -a --format '{{.Names}}' | grep "^tailscale$")
    local ts_status="${BG_R} DOWN ${RESET}"
    local ts_ip="${GREY}N/A${RESET}"
    
    if [[ -n "$ts_container_check" ]]; then
        if [[ $(docker ps --format '{{.Names}}' | grep "^tailscale$") ]]; then
            ts_status="${BG_G} ACTIVE ${RESET}"
            ts_ip="${C}$(get_ts_ip)${RESET}"
        else
            ts_status="${Y}${BOLD} STOPPED ${RESET}"
        fi
    fi

    echo -e "${BG_BLUE}${BOLD}  ⚡ SERVER CONTROL CENTER ${RESET}${B}${RESET} ${DIM}v2.0${RESET}"
    echo -e "  ${BOLD}┌$(printf '─%.0s' {1..50})┐${RESET}"
    echo -e "  ${BOLD}│${RESET}  ${C}USER:${RESET} $user @ $host"
    echo -e "  ${BOLD}│${RESET}  ${C}LOAD:${RESET} $load"
    echo -e "  ${BOLD}├$(printf '─%.0s' {1..50})┤${RESET}"
    echo -e "  ${BOLD}│${RESET}  ${W}Docker:${RESET}    $doc_status"
    echo -e "  ${BOLD}│${RESET}  ${W}Tailscale:${RESET} $ts_status  ${GREY}➜${RESET} $ts_ip"
    echo -e "  ${BOLD}└$(printf '─%.0s' {1..50})┘${RESET}"
}

# --- 4. CORE FUNCTIONS ---
install_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "  ${B}[+]${RESET} Installing Docker Engine..."
        curl -fsSL https://get.docker.com | sh
        sudo systemctl enable --now docker
    fi
}

manage_ts() {
    local action=$1
    if ! docker ps -a --format '{{.Names}}' | grep -q "^tailscale$"; then
        echo -e "  ${R}[!] Error: Tailscale container not found. Install it first.${RESET}"
        pause; return
    fi

    case $action in
        start)   docker start tailscale >/dev/null && echo -e "  ${G}[✓] Container Started${RESET}" ;;
        stop)    docker stop tailscale >/dev/null && echo -e "  ${Y}[!] Container Stopped${RESET}" ;;
        restart) docker restart tailscale >/dev/null && echo -e "  ${B}[↻] Container Restarted${RESET}" ;;
    esac
    sleep 1
}

install_tailscale() {
    draw_header
    install_docker
    
    echo -e "  ${BOLD}Tailscale Deployment${RESET}"
    read -p "  Enter Auth Key -> " TSKEY
    
    docker volume create tailscale-data >/dev/null 2>&1
    docker rm -f tailscale >/dev/null 2>&1

    echo -ne "  ${B}[+]${RESET} Launching Container... "
    docker run -d --name tailscale --hostname=$(hostname) \
      --cap-add=NET_ADMIN --cap-add=SYS_MODULE --device=/dev/net/tun \
      --network=host -e TS_AUTHKEY=$TSKEY -e TS_STATE_DIR=/var/lib/tailscale \
      -v tailscale-data:/var/lib/tailscale --restart=always tailscale/tailscale:latest >/dev/null

    echo -e "${G}Done!${RESET}"
    [[ -z "$TSKEY" ]] && echo -e "  ${Y}[!] Check logs (docker logs tailscale) for login URL.${RESET}"
    pause
}

# --- 5. MENUS ---
tailscale_menu() {
    while true; do
        draw_header
        echo -e "  ${BOLD}${M}TAILSCALE MANAGEMENT${RESET}"
        echo -e "  ${G}1.${RESET} Install"
        echo -e "  ${G}2.${RESET} Start "
        echo -e "  ${R}3.${RESET} Stop "
        echo -e "  ${B}4.${RESET} Restart"
        echo -e "  ${R}5.${RESET} Uninstall"
        echo -e "  ${C}6.${RESET} Network Info"
        echo -e "  ${GREY}0. Back to Main Menu${RESET}"
        echo
        read -p "  Selection ➤ " opt

        case $opt in
            1) install_tailscale ;;
            2) manage_ts start ;;
            3) manage_ts stop ;;
            4) manage_ts restart ;;
            5) 
                read -p "  Are you sure? (y/N): " confirm
                if [[ $confirm == [yY] ]]; then
                    docker rm -f tailscale && echo -e "  ${G}Removed.${RESET}"
                    pause
                fi
                ;;
            6) 
                draw_header
                echo -e "  ${BOLD}NETWORK STATUS${RESET}"
                echo -e "  ${W}Public IP:   ${RESET}$(curl -s --connect-timeout 2 ifconfig.me || echo 'Timeout')"
                echo -e "  ${W}Tailscale:   ${RESET}$(get_ts_ip)"
                echo -e "  ${W}Local Net:   ${RESET}$(hostname -I | awk '{print $1}')"
                pause 
                ;;
            0) break ;;
        esac
    done
}

# --- 6. MAIN ---
while true; do
    draw_header
    echo -e "  ${BOLD}MAIN MENU${RESET}"
    echo -e "  ${C}1.${RESET} Manage Tailscale"
    echo -e "  ${C}2.${RESET} System Logs (Tailscale)"
    echo -e "  ${R}0.${RESET} Exit System"
    echo
    read -p "  Selection ➤ " opt

    case $opt in
        1) tailscale_menu ;;
        2) docker logs --tail 20 tailscale; pause ;;
        0) clear; echo -e "\n  ${G}👋 Session Ended.${RESET}\n"; exit 0 ;;
        *) echo -e "  ${R}Invalid Selection${RESET}"; sleep 1 ;;
    esac
done
