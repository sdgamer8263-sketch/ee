#!/bin/bash

# --- COLOR DEFINITIONS ---
BOLD='\033[1m'
NC='\033[0m'
SUCCESS='\033[0;32m'
INFO='\033[0;34m'
WARN='\033[0;33m'
DANGER='\033[0;31m'
ACCENT='\033[0;35m'

CONTAINER_NAME="win2016"

# --- MAIN LOOP ---
while true; do
    # 1. AUTO DETECTION LOGIC
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        STATUS="${SUCCESS}RUNNING${NC}"
    elif [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
        STATUS="${WARN}STOPPED${NC}"
    else
        STATUS="${DANGER}NOT INSTALLED${NC}"
    fi

    # 2. UI HEADER
    clear
    echo -e "${ACCENT}────────────────────────────────────────────${NC}"
    echo -e "          ${BOLD}WINDOWS 2016 MANAGER${NC}"
    echo -e "${ACCENT}────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}STATUS:${NC}    $STATUS"
    echo -e "  ${BOLD}LOCAL IP:${NC}  $LOCAL_IP"
    echo -e "  ${BOLD}WEB UI:${NC}    http://$LOCAL_IP:6080"
    echo -e "${ACCENT}────────────────────────────────────────────${NC}"
    
    # 3. MENU OPTIONS
    echo -e "  ${BOLD}[1]${NC} ${SUCCESS}Install Windows 2016${NC}"
    echo -e "  ${BOLD}[2]${NC} ${INFO}Turn ON${NC}"
    echo -e "  ${BOLD}[3]${NC} ${WARN}Turn OFF${NC}"
    echo -e "  ${BOLD}[4]${NC} ${ACCENT}Restart${NC}"
    echo -e "  ${BOLD}[5]${NC} ${DANGER}Uninstall (Clear All)${NC}"
    echo -e "  ${BOLD}[6]${NC} Login Info"
    echo -e "  ${BOLD}[0]${NC} Exit"
    echo -e "${ACCENT}────────────────────────────────────────────${NC}"
    
    read -p " Select option [0-6]: " choice

    case $choice in
        1)
            echo -e "${INFO}Starting Installation...${NC}"
            docker run -d \
                --name $CONTAINER_NAME \
                --privileged \
                --device /dev/kvm \
                -p 6080:6080 \
                nobitaa/windows2016
            echo -e "${SUCCESS}Installation Command Sent!${NC}"
            sleep 3
            ;;
        2)
            echo -e "${INFO}Starting Container...${NC}"
            docker start $CONTAINER_NAME
            sleep 2
            ;;
        3)
            echo -e "${WARN}Stopping Container...${NC}"
            docker stop $CONTAINER_NAME
            sleep 2
            ;;
        4)
            echo -e "${ACCENT}Restarting...${NC}"
            docker restart $CONTAINER_NAME
            sleep 2
            ;;
        5)
            echo -e "${DANGER}Removing Windows 2016...${NC}"
            docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME
            echo -e "${SUCCESS}Cleaned Up Successfully.${NC}"
            sleep 2
            ;;
        6)
            clear
            echo -e "${BOLD}--- LOGIN INFORMATION ---${NC}"
            echo -e "URL: http://$LOCAL_IP:6080"
            echo -e "Username: Administrator"
            echo -e "Password: Admin@123"
            echo ""
            read -p "Press Enter to return to menu..."
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${DANGER}Invalid Option!${NC}"
            sleep 1
            ;;
    esac
done
