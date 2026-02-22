#!/bin/bash

# Function for the Banner
show_banner() {
    clear
    echo -e "\e[1;31m"
    echo "  ██████  ██████   ██████   █████  ███    ███ ███████ ██████  "
    echo " ██       ██   ██ ██       ██   ██ ████  ████ ██      ██   ██ "
    echo "  █████   ██   ██ ██   ███ ███████ ██ ████ ██ █████   ██████  "
    echo "      ██  ██   ██ ██    ██ ██   ██ ██  ██  ██ ██      ██   ██ "
    echo "  ██████  ██████   ██████  ██   ██ ██      ██ ███████ ██   ██ "
    echo -e "\e[0m"
    echo -e "\e[1;34m  ---------------------------------------------------------- \e[0m"
    echo -e "\e[1;32m             AUTO INSTALLER BY SDGAMER               \e[0m"
    echo -e "\e[1;34m  ---------------------------------------------------------- \e[0m"
}

# Function to pause and wait for Enter
pause_and_return() {
    echo -e "\n\e[32m[✔] Task Finished. Press Enter to go back to Menu...\e[0m"
    read -r
}

while true; do
    show_banner
    
    echo -e "  \e[1;33m[1]\e[0m  Cockpit"
    echo -e "  \e[1;33m[2]\e[0m  SSH"
    echo -e "  \e[1;33m[3]\e[0m  Casa OS"
    echo -e "  \e[1;33m[4]\e[0m  Pure Docker"
    echo -e "  \e[1;33m[5]\e[0m  Kali RDP"
    echo -e "  \e[1;33m[6]\e[0m  Localtonet (PORT FORWARDING)"
    echo -e "  \e[1;33m[7]\e[0m  LXC/LXD"
    echo -e "  \e[1;33m[8]\e[0m  Panel"
    echo -e "  \e[1;33m[9]\e[0m  Tailscale"
    echo -e "  \e[1;33m[10]\e[0m Windows 16"
    echo -e "  \e[1;31m[0]\e[0m  Exit"
    echo ""
    
    read -p "  Enter choice: " choice

    case $choice in
        1)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/Cockpit.sh) ; pause_and_return ;;
        2)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/SSH.sh) ; pause_and_return ;;
        3)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/casaos.sh) ; pause_and_return ;;
        4)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/doc.sh) ; pause_and_return ;;
        5)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/kali-rdp.sh) ; pause_and_return ;;
        6)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/localtonet.sh) ; pause_and_return ;;
        7)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/lxc.sh) ; pause_and_return ;;
        8)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/panel.sh) ; pause_and_return ;;
        9)  bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/tailscale.sh) ; pause_and_return ;;
        10) bash <(curl -sL https://raw.githubusercontent.com/sdgamer8263-sketch/ee/main/win16.sh) ; pause_and_return ;;
        0)  echo -e "\e[1;32mExiting... Happy Hacking!\e[0m"; break ;;
        *)  echo -e "\e[1;31mInvalid selection!\e[0m"; sleep 1 ;;
    esac
done
