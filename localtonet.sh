#!/bin/bash

# Configuration
CONTAINER_NAME="localtonet"
IMAGE_NAME="localtonet/localtonet"

# UI Colors
P_BLUE='\033[38;5;81m'
P_MAGENTA='\033[38;5;201m'
P_ORANGE='\033[38;5;208m'
P_RED='\033[38;5;196m'
P_GREEN='\033[38;5;82m'
NC='\033[0m'
BOLD='\033[1m'

while true; do
    clear
    # --- Auto-Detection Logic ---
    if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
        STATUS_LBL="${P_GREEN}ONLINE${NC}"
        COLOR=$P_GREEN
    elif [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
        STATUS_LBL="${P_ORANGE}OFFLINE${NC}"
        COLOR=$P_ORANGE
    else
        STATUS_LBL="${P_RED}NOT INSTALLED${NC}"
        COLOR=$P_RED
    fi

    # --- Header & Sidebar UI ---
    echo -e "${P_BLUE}◢◤ LOCALTONET CONTROL CENTER${NC}"
    echo -e "${P_BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
    echo -e " STATUS  │ $STATUS_LBL"
    echo -e " IMAGE   │ ${BOLD}$IMAGE_NAME${NC}"
    echo -e "${P_BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
    echo -e "${P_MAGENTA}  [1]${NC} Initialize Tunnel      ${P_MAGENTA}▐${NC}"
    echo -e "${P_MAGENTA}  [2]${NC} Check Health           ${P_MAGENTA}▐${NC}"
    echo -e "${P_MAGENTA}  [3]${NC} Live Stream Logs       ${P_MAGENTA}▐${NC}  ${BOLD}CORE ACTIONS${NC}"
    echo -e "${P_MAGENTA}  [4]${NC} Soft Restart           ${P_MAGENTA}▐${NC}"
    echo -e "${P_BLUE}  ───${NC}                        ${P_MAGENTA}▐${NC}"
    echo -e "${P_MAGENTA}  [5]${NC} Power ON               ${P_MAGENTA}▐${NC}"
    echo -e "${P_MAGENTA}  [6]${NC} Power OFF              ${P_MAGENTA}▐${NC}  ${BOLD}POWER SETTINGS${NC}"
    echo -e "${P_BLUE}  ───${NC}                        ${P_MAGENTA}▐${NC}"
    echo -e "${P_RED}  [7]  UNINSTALL MENU        ${P_MAGENTA}▐${NC}  ${P_RED}DANGER ZONE${NC}"
    echo -e "${P_MAGENTA}  [8]${NC} Exit Terminal          ${P_MAGENTA}▐${NC}"
    echo -e "${P_BLUE}▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬${NC}"
    echo ""
    read -p " COMMAND › " choice

    case $choice in
        1)
            read -p " 🔑 Enter Token: " TOKEN
            docker run -d --name $CONTAINER_NAME --restart unless-stopped $IMAGE_NAME --authtoken "$TOKEN"
            ;;
        2)
            docker inspect -f '{{.State.Status}}' $CONTAINER_NAME 2>/dev/null || echo "No container found."
            sleep 2
            ;;
        3)
            docker logs -f $CONTAINER_NAME
            ;;
        4) docker restart $CONTAINER_NAME ;;
        5) docker start $CONTAINER_NAME ;;
        6) docker stop $CONTAINER_NAME ;;
        7)
            # --- New Uninstall Sub-Menu ---
            clear
            echo -e "${P_RED}☠️  UNINSTALL OPTIONS${NC}"
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e " 1) Remove Container Only"
            echo -e " 2) Remove Image Only (${IMAGE_NAME})"
            echo -e " 3) FULL PURGE (Container + Image)"
            echo -e " 4) Cancel"
            echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -p " Select severity: " uninstall_choice
            
            case $uninstall_choice in
                1) docker rm -f $CONTAINER_NAME ;;
                2) docker rmi $IMAGE_NAME ;;
                3) 
                   docker rm -f $CONTAINER_NAME
                   docker rmi $IMAGE_NAME
                   echo -e "${P_GREEN}System purged.${NC}"
                   ;;
                *) echo "Aborted." ;;
            esac
            sleep 1
            ;;
        8)
            exit 0
            ;;
        *)
            echo -e "${P_RED}Invalid Command${NC}"
            sleep 1
            ;;
    esac
done
