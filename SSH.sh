#!/bin/bash

# ==================================================
#   SERVER CONTROL CENTER | SHELLNGN ONLY
# ==================================================

# --- 1. COLORS & STYLING ---
BG_BLUE="\e[44;97m"; BG_GREEN="\e[42;97m"; BG_RED="\e[41;97m"

R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; M="\e[35m"; W="\e[97m"; GREY="\e[90m"
RESET="\e[0m"
BOLD="\e[1m"

# --- 2. CONFIG ---
SHELLNGN_PORT_FILE="/root/.shellngn_port"

# --- 3. UTILITY ---
pause() { echo; read -p "  ↩ Press Enter to continue..." _; }

get_port() {
    if [ -f "$SHELLNGN_PORT_FILE" ]; then cat "$SHELLNGN_PORT_FILE"; else echo "8080"; fi
}

# --- 4. HEADER ---
draw_header() {
    clear
    local user=$(whoami)
    local host=$(hostname)

    # Docker Status
    local doc_pill="${BG_RED} OFF ${RESET}"
    if command -v docker &>/dev/null; then doc_pill="${BG_GREEN} ON  ${RESET}"; fi

    # ShellNGN Status
    local sng_pill="${BG_RED} OFF ${RESET}"
    if docker ps -a --format '{{.Names}}' | grep -q shellngn; then sng_pill="${BG_GREEN} ON  ${RESET}"; fi
    local sng_port=$(get_port)

    echo -e "${BG_BLUE}${BOLD}  ⚡ SERVER CONTROL CENTER | SHELLNGN                 ${RESET}"
    echo -e "  ${C}User:${RESET} $user   ${GREY}|${RESET}   ${C}Host:${RESET} $host"
    echo -e "  ${M}────────────────────────────────────────────────────────────${RESET}"

    echo -e "  ${BOLD}SERVICES STATUS:${RESET}"
    printf "  ├── ${W}%-10s${RESET} %b\n" "Docker" "$doc_pill"
    printf "  └── ${W}%-10s${RESET} %b  ${GREY}➜ Port: ${Y}$sng_port${RESET}\n" "ShellNGN" "$sng_pill"

    echo -e "  ${M}────────────────────────────────────────────────────────────${RESET}"
    echo
}

# --- 5. INSTALL DOCKER ---
install_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "  ${B}[+] Installing Docker...${RESET}"
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
    fi
}

# --- 6. SHELLNGN FUNCTIONS ---
install_shellngn() {
    draw_header
    install_docker

    echo -e "  ${BOLD}┌── [ INSTALL SHELLNGN ]${RESET}"
    echo -e "  ${BOLD}│${RESET}"
    echo -e "  ${GREY}[${Y}1${GREY}]${RESET} Default Port ${C}(8080)${RESET}"
    echo -e "  ${GREY}[${Y}2${GREY}]${RESET} Custom Port"
    echo -e "  ${BOLD}│${RESET}"
    read -p "  └─➤ Select Option: " port_choice

    if [ "$port_choice" == "2" ]; then
        read -p "    ➤ Enter Custom Port: " CUSTOM_PORT
        PORT=$CUSTOM_PORT
    else
        PORT=8080
    fi

    echo "$PORT" > "$SHELLNGN_PORT_FILE"

    echo -e "\n  ${B}[+] Installing ShellNGN on port ${PORT}...${RESET}"

    docker rm -f shellngn >/dev/null 2>&1
    docker run -d --name shellngn -p ${PORT}:8080 --restart=always shellngn/pro:latest

    echo -e "  ${G}[✓] Installed! Access: http://$host:${PORT}${RESET}"
    pause
}

uninstall_shellngn() {
    echo -e "\n  ${R}[!] Removing ShellNGN...${RESET}"
    docker rm -f shellngn >/dev/null 2>&1
    rm -f "$SHELLNGN_PORT_FILE"
    echo -e "  ${G}[✓] Removed Successfully.${RESET}"
    pause
}

start_shellngn() {
    docker start shellngn
    echo -e "  ${G}[✓] ShellNGN Started${RESET}"
    pause
}

stop_shellngn() {
    docker stop shellngn
    echo -e "  ${R}[!] ShellNGN Stopped${RESET}"
    pause
}

restart_shellngn() {
    docker restart shellngn
    echo -e "  ${Y}[↻] ShellNGN Restarted${RESET}"
    pause
}

# --- 7. SHELLNGN MENU ---
shellngn_menu() {
    while true; do
        draw_header
        echo -e "  ${BOLD}SHELLNGN OPTIONS:${RESET}"
        echo -e "  ${GREY}[${Y}1${GREY}]${RESET} ${G}Install${RESET}"
        echo -e "  ${GREY}[${Y}2${GREY}]${RESET} ${G}Turn ON${RESET}"
        echo -e "  ${GREY}[${Y}3${GREY}]${RESET} ${R}Turn OFF${RESET}"
        echo -e "  ${GREY}[${Y}4${GREY}]${RESET} ${Y}Restart${RESET}"
        echo -e "  ${GREY}[${Y}5${GREY}]${RESET} ${R}Uninstall${RESET}"
        echo -e "  ${GREY}[${R}0${GREY}]${RESET} Exit"
        echo

        read -p "  > Select: " opt
        case $opt in
            1) install_shellngn ;;
            2) start_shellngn ;;
            3) stop_shellngn ;;
            4) restart_shellngn ;;
            5) uninstall_shellngn ;;
            0) echo -e "\n  ${G}👋 Goodbye!${RESET}"; exit 0 ;;
            *) echo -e "  ${R}Invalid option${RESET}"; sleep 1 ;;
        esac
    done
}

# --- RUN ---
shellngn_menu
