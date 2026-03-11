#!/bin/bash
# lxc-manager.sh - Complete LXC Management with Auto-Detect & Auto-Fix
# Version: 4.0
# Author: LXC Manager
# Description: Complete LXC container management with auto-detect, auto-install, and auto-fix features

# =====================================================================
# CONFIGURATION
# =====================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Files and directories
CONFIG_DIR="$HOME/.lxc-manager"
CONFIG_FILE="$CONFIG_DIR/config.cfg"
LOG_FILE="$CONFIG_DIR/lxc-manager.log"
DB_FILE="$CONFIG_DIR/lxc_containers.db"
BACKUP_DIR="$CONFIG_DIR/backups"
MONITOR_FILE="$CONFIG_DIR/monitor.json"
CACHE_FILE="$CONFIG_DIR/cache.db"
TEMP_DIR="/tmp/lxc-manager"

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$TEMP_DIR"

# =====================================================================
# LOGGING FUNCTIONS
# =====================================================================

log() {
    local level="$1"
    local message="$2"
    local color="$NC"
    local prefix=""
    
    case "$level" in
        "SUCCESS") color="$GREEN"; prefix="[SUCCESS]" ;;
        "ERROR") color="$RED"; prefix="[ERROR]" ;;
        "WARNING") color="$YELLOW"; prefix="[WARNING]" ;;
        "INFO") color="$CYAN"; prefix="[INFO]" ;;
        "DEBUG") color="$PURPLE"; prefix="[DEBUG]" ;;
    esac
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${color}${prefix} ${timestamp} - ${message}${NC}" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$1"; }
log_success() { log "SUCCESS" "$1"; }
log_error() { log "ERROR" "$1"; }
log_warning() { log "WARNING" "$1"; }

# =====================================================================
# UTILITY FUNCTIONS
# =====================================================================

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                        LXC CONTAINER MANAGER v4.0                         ${BLUE}║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${GREEN}                 Auto-Detect • Auto-Install • Auto-Fix • Auto-Manage                ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${CYAN}$1${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════════════════════${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_failure() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

progress_bar() {
    local duration=$1
    local steps=20
    local step_delay=$(echo "scale=3; $duration/$steps" | bc)
    
    echo -ne "${BLUE}["
    for ((i=0; i<steps; i++)); do
        echo -ne "█"
        sleep $step_delay
    done
    echo -e "]${NC}"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    echo -n " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# =====================================================================
# SYSTEM DETECTION & INSTALLATION
# =====================================================================

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
        OS_ID_LIKE="$ID_LIKE"
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
        OS_ID="unknown"
        OS_ID_LIKE="unknown"
    fi
    
    log_info "Detected OS: $OS_NAME $OS_VERSION ($OS_ID)"
}

detect_resources() {
    # CPU
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | xargs)
    CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo)
    
    # RAM
    TOTAL_RAM=$(free -g | awk 'NR==2{print $2}')
    AVAILABLE_RAM=$(free -g | awk 'NR==2{print $7}')
    USED_RAM=$((TOTAL_RAM - AVAILABLE_RAM))
    
    # Disk
    TOTAL_DISK=$(df -h / | awk 'NR==2{print $2}')
    AVAILABLE_DISK=$(df -h / | awk 'NR==2{print $4}')
    DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    DISK_USED=$(df -h / | awk 'NR==2{print $3}')
    
    # Network
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    IP_ADDRESS=$(ip addr show $DEFAULT_INTERFACE 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 || echo "N/A")
    
    log_info "Resources: CPU: $CPU_CORES cores, RAM: ${TOTAL_RAM}GB, Disk: $TOTAL_DISK"
}

check_lxc_installation() {
    log_info "Checking LXC/LXD installation..."
    
    local lxc_installed=false
    local lxd_installed=false
    
    if command -v lxc &> /dev/null; then
        lxc_installed=true
        LXC_VERSION=$(lxc --version 2>/dev/null || echo "Unknown")
    fi
    
    if command -v lxd &> /dev/null; then
        lxd_installed=true
        LXD_VERSION=$(lxd --version 2>/dev/null || echo "Unknown")
    fi
    
    if $lxc_installed && $lxd_installed; then
        log_success "LXC $LXC_VERSION and LXD $LXD_VERSION are installed"
        return 0
    else
        log_warning "LXC/LXD not fully installed"
        return 1
    fi
}

install_lxc() {
    print_section "LXC INSTALLATION"
    
    detect_os
    
    echo -e "${YELLOW}Installing LXC/LXD on $OS_NAME $OS_VERSION...${NC}"
    echo ""
    
    case $OS_ID in
        ubuntu)
            install_lxc_ubuntu
            ;;
        debian)
            install_lxc_debian
            ;;
        centos|rhel)
            install_lxc_centos
            ;;
        fedora)
            install_lxc_fedora
            ;;
        arch)
            install_lxc_arch
            ;;
        *)
            install_lxc_generic
            ;;
    esac
    
    # Verify installation
    verify_installation
}

install_lxc_ubuntu() {
    echo -e "${CYAN}Installing on Ubuntu...${NC}"
    
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y lxc lxc-utils bridge-utils
    
    # Install LXD via snap
    if ! command -v snap &> /dev/null; then
        sudo apt install -y snapd
    fi
    sudo systemctl enable --now snapd.socket
    sudo snap install lxd
    
    # Add user to lxd group
    sudo usermod -aG lxd $USER
    newgrp lxd
    
    log_success "LXC/LXD installed on Ubuntu"
}

install_lxc_debian() {
    echo -e "${CYAN}Installing on Debian...${NC}"
    
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y snapd bridge-utils uidmap
    sudo systemctl enable --now snapd.socket
    sudo ln -s /var/lib/snapd/snap /snap
    sudo snap install lxd
    sudo usermod -aG lxd $USER
    newgrp lxd
    sudo apt install -y lxc lxc-utils
    
    log_success "LXC/LXD installed on Debian"
}

install_lxc_centos() {
    echo -e "${CYAN}Installing on CentOS/RHEL...${NC}"
    
    sudo yum install -y epel-release
    sudo yum install -y lxc lxc-templates lxc-extra bridge-utils
    
    # Install snap if available
    if command -v dnf &> /dev/null; then
        sudo dnf install -y snapd
    else
        sudo yum install -y snapd
    fi
    
    sudo systemctl enable --now snapd.socket
    sudo ln -s /var/lib/snapd/snap /snap
    sudo snap install lxd
    sudo usermod -aG lxd $USER
    newgrp lxd
    
    log_success "LXC/LXD installed on CentOS"
}

install_lxc_fedora() {
    echo -e "${CYAN}Installing on Fedora...${NC}"
    
    sudo dnf install -y lxc lxc-templates lxc-extra bridge-utils snapd
    sudo systemctl enable --now snapd.socket
    sudo ln -s /var/lib/snapd/snap /snap
    sudo snap install lxd
    sudo usermod -aG lxd $USER
    newgrp lxd
    
    log_success "LXC/LXD installed on Fedora"
}

install_lxc_arch() {
    echo -e "${CYAN}Installing on Arch Linux...${NC}"
    
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm lxc lxc-templates bridge-utils dnsmasq
    sudo pacman -S --noconfirm lxd
    sudo usermod -aG lxd $USER
    newgrp lxd
    
    log_success "LXC/LXD installed on Arch Linux"
}

install_lxc_generic() {
    echo -e "${CYAN}Attempting generic installation...${NC}"
    
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y lxc lxc-utils bridge-utils
    elif command -v yum &> /dev/null; then
        sudo yum install -y lxc lxc-templates bridge-utils
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y lxc lxc-templates bridge-utils
    elif command -v pacman &> /dev/null; then
        sudo pacman -Syu --noconfirm lxc bridge-utils
    else
        log_error "Cannot detect package manager"
        return 1
    fi
    
    log_success "LXC installed via generic method"
}

verify_installation() {
    print_section "VERIFICATION"
    
    local success=true
    
    # Check LXC
    if command -v lxc &> /dev/null; then
        print_status "LXC: $(lxc --version)"
    else
        print_failure "LXC not found"
        success=false
    fi
    
    # Check LXD
    if command -v lxd &> /dev/null; then
        print_status "LXD: $(lxd --version)"
    else
        print_failure "LXD not found"
        success=false
    fi
    
    # Check LXD service
    if systemctl is-active --quiet lxd; then
        print_status "LXD service: Running"
    else
        print_warning "LXD service: Not running (starting...)"
        sudo systemctl start lxd
        sudo systemctl enable lxd
    fi
    
    # Test LXC command
    if lxc list &>/dev/null; then
        print_status "LXC test: Successful"
    else
        print_warning "LXC test: Failed (may need initialization)"
    fi
    
    if $success; then
        log_success "LXC installation verified"
    else
        log_error "LXC installation has issues"
    fi
}

initialize_lxd() {
    print_section "LXD INITIALIZATION"
    
    if lxc storage list &>/dev/null 2>&1; then
        log_info "LXD is already initialized"
        return 0
    fi
    
    echo -e "${YELLOW}LXD needs to be initialized.${NC}"
    echo ""
    echo "Options:"
    echo "  1. Auto-initialize (Recommended)"
    echo "  2. Interactive initialization"
    echo "  3. Skip for now"
    echo ""
    
    read -p "Select option (1-3): " init_choice
    
    case $init_choice in
        1)
            echo -e "\n${CYAN}Auto-initializing LXD...${NC}"
            sudo lxd init --auto
            ;;
        2)
            echo -e "\n${CYAN}Interactive LXD initialization...${NC}"
            sudo lxd init
            ;;
        3)
            log_warning "Skipping LXD initialization"
            return 0
            ;;
        *)
            sudo lxd init --auto
            ;;
    esac
    
    # Wait for initialization
    sleep 3
    
    if lxc storage list &>/dev/null; then
        log_success "LXD initialized successfully"
        return 0
    else
        log_error "LXD initialization failed"
        return 1
    fi
}

# =====================================================================
# NETWORK MANAGEMENT
# =====================================================================

check_network_bridge() {
    log_info "Checking network bridges..."
    
    local bridges=$(lxc network list --format csv 2>/dev/null | grep bridge | cut -d',' -f1 | tr '\n' ' ')
    
    if [ -z "$bridges" ]; then
        log_warning "No network bridges found"
        return 1
    else
        log_info "Available bridges: $bridges"
        return 0
    fi
}

create_default_bridge() {
    print_section "NETWORK BRIDGE CREATION"
    
    echo -e "${YELLOW}Creating default network bridge 'lxdbr0'...${NC}"
    
    # Check if bridge already exists
    if lxc network list --format csv 2>/dev/null | grep -q "^lxdbr0,"; then
        log_info "Bridge 'lxdbr0' already exists"
        return 0
    fi
    
    # Try to create bridge
    echo -e "${CYAN}Attempt 1: Simple bridge creation...${NC}"
    if sudo lxc network create lxdbr0 2>/dev/null; then
        log_success "Bridge 'lxdbr0' created successfully"
        return 0
    fi
    
    echo -e "${CYAN}Attempt 2: Bridge with IPv4 NAT...${NC}"
    if sudo lxc network create lxdbr0 ipv4.address=auto ipv4.nat=true ipv6.address=none 2>/dev/null; then
        log_success "Bridge 'lxdbr0' created with IPv4 NAT"
        return 0
    fi
    
    echo -e "${CYAN}Attempt 3: Using LXD auto-init...${NC}"
    if sudo lxd init --auto 2>/dev/null; then
        log_success "LXD auto-init completed"
        return 0
    fi
    
    log_error "Failed to create network bridge"
    return 1
}

fix_network_issues() {
    print_section "NETWORK ISSUE RESOLUTION"
    
    local issues_fixed=0
    
    # 1. Check LXD service
    if ! systemctl is-active --quiet lxd; then
        print_warning "LXD service not running"
        sudo systemctl start lxd
        sudo systemctl enable lxd
        print_status "LXD service started"
        issues_fixed=$((issues_fixed+1))
    fi
    
    # 2. Check network bridge
    if ! check_network_bridge; then
        print_warning "No network bridge found"
        if create_default_bridge; then
            issues_fixed=$((issues_fixed+1))
        fi
    fi
    
    # 3. Check firewall
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        print_warning "UFW firewall active, adding LXD rules..."
        sudo ufw allow in on lxdbr0
        sudo ufw route allow in on lxdbr0
        sudo ufw route allow out on lxdbr0
        issues_fixed=$((issues_fixed+1))
    fi
    
    # 4. Check iptables
    if command -v iptables &> /dev/null; then
        print_warning "Checking iptables rules..."
        sudo iptables -I FORWARD -i lxdbr0 -j ACCEPT
        sudo iptables -I FORWARD -o lxdbr0 -j ACCEPT
    fi
    
    if [ $issues_fixed -gt 0 ]; then
        log_success "Fixed $issues_fixed network issues"
    else
        log_info "No network issues found"
    fi
    
    # Restart LXD to apply changes
    print_warning "Restarting LXD service..."
    sudo systemctl restart lxd
    sleep 5
    
    return 0
}

# =====================================================================
# CONTAINER MANAGEMENT
# =====================================================================

list_containers() {
    print_section "CONTAINERS LIST"
    
    if ! check_lxc_installation; then
        log_error "LXC not installed"
        return 1
    fi
    
    local format="table {{.Names}}\t{{.Status}}\t{{.IPv4}}\t{{.IPv6}}\t{{.Type}}\t{{.Architecture}}"
    
    echo -e "${GREEN}Live Containers:${NC}"
    lxc list --format "$format"
    
    # Show container statistics
    local total=$(lxc list --format csv 2>/dev/null | wc -l)
    local running=$(lxc list --format csv 2>/dev/null | grep -c "RUNNING")
    local stopped=$(lxc list --format csv 2>/dev/null | grep -c "STOPPED")
    
    echo -e "\n${CYAN}Statistics:${NC}"
    echo -e "  Total containers: $total"
    echo -e "  Running: $running"
    echo -e "  Stopped: $stopped"
}

create_container_smart() {
    print_section "SMART CONTAINER CREATION"
    
    if ! check_lxc_installation; then
        log_error "LXC not installed"
        return 1
    fi
    
    # Check network
    if ! check_network_bridge; then
        log_warning "Network bridge not found. Creating one..."
        if ! create_default_bridge; then
            log_error "Cannot create container without network bridge"
            return 1
        fi
    fi
    
    # Get available bridges
    local bridges=$(lxc network list --format csv 2>/dev/null | grep bridge | cut -d',' -f1 | tr '\n' ',' | sed 's/,$//')
    local default_bridge=$(echo "$bridges" | cut -d',' -f1)
    
    # Get available profiles
    local profiles=$(lxc profile list --format csv 2>/dev/null | cut -d',' -f1 | tr '\n' ',' | sed 's/,$//')
    local default_profile=$(echo "$profiles" | cut -d',' -f1)
    
    # Auto-detect resource limits
    detect_resources
    local max_ram=$((AVAILABLE_RAM * 80 / 100))
    local max_cpu=$((CPU_CORES * 80 / 100))
    local max_disk=$(df -m / | awk 'NR==2{print $4}')
    max_disk=$((max_disk / 1024 * 80 / 100))
    
    # Container name
    local default_name="container-$(date +%Y%m%d-%H%M%S)"
    echo -e "${CYAN}Container Name:${NC}"
    read -p "  (default: $default_name): " container_name
    container_name=${container_name:-$default_name}
    
    # Check if name exists
    if lxc list -c n --format csv 2>/dev/null | grep -q "^$container_name$"; then
        log_error "Container '$container_name' already exists!"
        return 1
    fi
    
    # RAM selection
    echo -e "\n${CYAN}RAM Allocation:${NC}"
    echo "  1. Small (1GB)     - Lightweight apps"
    echo "  2. Medium (2GB)    - Web servers"
    echo "  3. Large (4GB)     - Databases"
    echo "  4. X-Large (8GB)   - Heavy applications"
    echo "  5. Custom"
    
    read -p "  Select (1-5): " ram_choice
    case $ram_choice in
        1) ram=1 ;;
        2) ram=2 ;;
        3) ram=4 ;;
        4) ram=8 ;;
        5) 
            read -p "  Custom RAM (GB, max $max_ram): " ram
            if [ $ram -gt $max_ram ]; then
                ram=$max_ram
                log_warning "Limited to $max_ram GB"
            fi
            ;;
        *) ram=2 ;;
    esac
    
    # CPU selection
    echo -e "\n${CYAN}CPU Cores:${NC}"
    echo "  1. 1 core     - Light load"
    echo "  2. 2 cores    - Standard"
    echo "  3. 4 cores    - High performance"
    echo "  4. Custom"
    
    read -p "  Select (1-4): " cpu_choice
    case $cpu_choice in
        1) cpu=1 ;;
        2) cpu=2 ;;
        3) cpu=4 ;;
        4) 
            read -p "  Custom CPU cores (max $max_cpu): " cpu
            if [ $cpu -gt $max_cpu ]; then
                cpu=$max_cpu
                log_warning "Limited to $max_cpu cores"
            fi
            ;;
        *) cpu=2 ;;
    esac
    
    # Disk selection
    echo -e "\n${CYAN}Disk Space:${NC}"
    echo "  1. Small (10GB)    - OS only"
    echo "  2. Medium (20GB)   - OS + apps"
    echo "  3. Large (50GB)    - OS + apps + data"
    echo "  4. X-Large (100GB) - Large datasets"
    echo "  5. Custom"
    
    read -p "  Select (1-5): " disk_choice
    case $disk_choice in
        1) disk=10 ;;
        2) disk=20 ;;
        3) disk=50 ;;
        4) disk=100 ;;
        5) 
            read -p "  Custom disk (GB, max $max_disk): " disk
            if [ $disk -gt $max_disk ]; then
                disk=$max_disk
                log_warning "Limited to $max_disk GB"
            fi
            ;;
        *) disk=20 ;;
    esac
    
    # OS selection
    echo -e "\n${CYAN}Operating System:${NC}"
    echo "  1. Ubuntu 22.04 LTS     - General purpose"
    echo "  2. Debian 12            - Stable servers"
    echo "  3. Alpine Linux         - Lightweight"
    echo "  4. CentOS 9             - Enterprise"
    echo "  5. Show all available"
    echo "  6. Custom image"
    
    read -p "  Select (1-6): " os_choice
    case $os_choice in
        1) os_image="ubuntu:22.04"; os_name="Ubuntu 22.04 LTS" ;;
        2) os_image="debian/12"; os_name="Debian 12" ;;
        3) os_image="alpine/edge"; os_name="Alpine Linux" ;;
        4) os_image="centos/9"; os_name="CentOS 9" ;;
        5) 
            echo -e "\n${YELLOW}Available images:${NC}"
            lxc image list images: --format csv | head -20 | awk -F',' '{print "  " $1 " - " $3}'
            read -p "  Enter image name: " os_image
            os_name=$(echo "$os_image" | cut -d':' -f1)
            ;;
        6)
            read -p "  Enter custom image: " os_image
            os_name="Custom"
            ;;
        *) os_image="ubuntu:22.04"; os_name="Ubuntu 22.04 LTS" ;;
    esac
    
    # Network bridge
    echo -e "\n${CYAN}Network Bridge:${NC}"
    echo "  Available: $bridges"
    read -p "  (default: $default_bridge): " network_bridge
    network_bridge=${network_bridge:-$default_bridge}
    
    # Profile
    echo -e "\n${CYAN}Profile:${NC}"
    echo "  Available: $profiles"
    read -p "  (default: $default_profile): " profile
    profile=${profile:-$default_profile}
    
    # Summary
    echo -e "\n${GREEN}📋 CREATION SUMMARY:${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  Name:     ${CYAN}$container_name${NC}"
    echo -e "  RAM:      ${CYAN}${ram}GB${NC}"
    echo -e "  CPU:      ${CYAN}${cpu} cores${NC}"
    echo -e "  Disk:     ${CYAN}${disk}GB${NC}"
    echo -e "  OS:       ${CYAN}$os_name${NC}"
    echo -e "  Network:  ${CYAN}$network_bridge${NC}"
    echo -e "  Profile:  ${CYAN}$profile${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    
    read -p "Create container? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Creation cancelled"
        return 0
    fi
    
    # Create container
    create_container "$container_name" "$ram" "$cpu" "$disk" "$os_image" "$network_bridge" "$profile"
}

create_container() {
    local name=$1
    local ram=$2
    local cpu=$3
    local disk=$4
    local image=$5
    local network=$6
    local profile=$7
    
    print_section "CREATING CONTAINER"
    
    log_info "Creating container '$name'..."
    
    # Validate network bridge
    if ! lxc network list --format csv 2>/dev/null | grep -q "^$network,"; then
        log_error "Network bridge '$network' not found"
        return 1
    fi
    
    # Launch container
    echo -e "${CYAN}Launching container...${NC}"
    if ! lxc launch "$image" "$name" --profile "$profile" --network "$network" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to launch container"
        return 1
    fi
    
    # Set resource limits
    echo -e "\n${CYAN}Configuring resources...${NC}"
    lxc config set "$name" limits.memory="${ram}GB"
    lxc config set "$name" limits.cpu="$cpu"
    
    # Resize disk
    lxc config device override "$name" root size="${disk}GB"
    
    # Wait for container
    echo -e "\n${CYAN}Waiting for container to initialize...${NC}"
    sleep 10
    
    # Get container info
    local ip_address=$(lxc list "$name" --format csv 2>/dev/null | cut -d',' -f6 | xargs)
    local status=$(lxc list "$name" --format csv 2>/dev/null | cut -d',' -f2 | xargs)
    
    # Display results
    echo -e "\n${GREEN}✅ CONTAINER CREATED SUCCESSFULLY${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  Name:       ${CYAN}$name${NC}"
    echo -e "  Status:     ${GREEN}$status${NC}"
    echo -e "  IP Address: ${CYAN}$ip_address${NC}"
    echo -e "  RAM:        ${CYAN}${ram}GB${NC}"
    echo -e "  CPU:        ${CYAN}${cpu} cores${NC}"
    echo -e "  Disk:       ${CYAN}${disk}GB${NC}"
    echo -e "  Image:      ${CYAN}$image${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    
    # Connection info
    echo -e "\n${GREEN}🔗 CONNECTION INFORMATION:${NC}"
    echo -e "  Console:    ${CYAN}lxc exec $name -- bash${NC}"
    echo -e "  SSH:        ${CYAN}ssh ubuntu@$ip_address${NC} (for Ubuntu)"
    echo -e "  Stop:       ${CYAN}lxc stop $name${NC}"
    echo -e "  Start:      ${CYAN}lxc start $name${NC}"
    echo -e "  Delete:     ${CYAN}lxc delete $name${NC}"
    
    # Auto-start option
    echo -e "\n${YELLOW}Enable auto-start on boot? (y/n):${NC}"
    read -r auto_start
    if [[ "$auto_start" == "y" || "$auto_start" == "Y" ]]; then
        lxc config set "$name" boot.autostart true
        log_success "Auto-start enabled"
    fi
    
    return 0
}

start_container() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    log_info "Starting container '$name'..."
    
    if lxc start "$name" 2>/dev/null; then
        log_success "Container '$name' started"
        return 0
    else
        log_error "Failed to start container '$name'"
        return 1
    fi
}

stop_container() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    log_info "Stopping container '$name'..."
    
    if lxc stop "$name" 2>/dev/null; then
        log_success "Container '$name' stopped"
        return 0
    else
        log_error "Failed to stop container '$name'"
        return 1
    fi
}

restart_container() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    log_info "Restarting container '$name'..."
    
    if lxc restart "$name" 2>/dev/null; then
        log_success "Container '$name' restarted"
        return 0
    else
        log_error "Failed to restart container '$name'"
        return 1
    fi
}

delete_container() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    # Confirm deletion
    echo -e "${RED}⚠️  WARNING: This will delete container '$name' and all its data!${NC}"
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Deletion cancelled"
        return 0
    fi
    
    log_info "Deleting container '$name'..."
    
    if lxc delete "$name" --force 2>/dev/null; then
        log_success "Container '$name' deleted"
        return 0
    else
        log_error "Failed to delete container '$name'"
        return 1
    fi
}

# =====================================================================
# CONTAINER CONTROLS
# =====================================================================

container_shell() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    log_info "Opening shell for '$name'..."
    lxc exec "$name" -- bash
}

container_info() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    print_section "CONTAINER INFO: $name"
    
    # Basic info
    lxc info "$name"
    
    # Resource usage
    echo -e "\n${CYAN}Resource Usage:${NC}"
    lxc exec "$name" -- free -h 2>/dev/null || echo "Unable to get memory info"
    echo ""
    lxc exec "$name" -- df -h / 2>/dev/null || echo "Unable to get disk info"
    
    # Processes
    echo -e "\n${CYAN}Top Processes:${NC}"
    lxc exec "$name" -- ps aux --sort=-%cpu | head -10 2>/dev/null || echo "Unable to get process info"
}

container_stats() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    print_section "LIVE STATS: $name"
    
    # Continuous monitoring
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring...${NC}"
    echo ""
    
    while true; do
        clear
        print_section "LIVE STATS: $name"
        
        # CPU usage
        local cpu=$(lxc exec "$name" -- top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' 2>/dev/null || echo "0")
        
        # Memory usage
        local mem_info=$(lxc exec "$name" -- free -m 2>/dev/null | awk 'NR==2{print $2" "$3}')
        local mem_total=$(echo "$mem_info" | awk '{print $1}')
        local mem_used=$(echo "$mem_info" | awk '{print $2}')
        local mem_percent=0
        if [ $mem_total -gt 0 ]; then
            mem_percent=$((mem_used * 100 / mem_total))
        fi
        
        # Disk usage
        local disk_info=$(lxc exec "$name" -- df -h / 2>/dev/null | awk 'NR==2{print $2" "$3" "$5}')
        
        # Network
        local network_info=$(lxc exec "$name" -- ip addr show 2>/dev/null | grep "inet " | head -1)
        
        # Display stats
        echo -e "${GREEN}CPU Usage:${NC} ${cpu}%"
        echo -e "${GREEN}Memory:${NC} ${mem_used}MB/${mem_total}MB (${mem_percent}%)"
        echo -e "${GREEN}Disk:${NC} $disk_info"
        echo -e "${GREEN}Network:${NC} $network_info"
        echo -e "\n${YELLOW}Updated: $(date '+%H:%M:%S')${NC}"
        
        sleep 2
    done
}

# =====================================================================
# BACKUP & RESTORE
# =====================================================================

backup_container() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    # Backup name
    local backup_name="${name}_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name.tar.gz"
    
    print_section "BACKUP CONTAINER"
    
    log_info "Backing up '$name' to '$backup_path'..."
    
    if lxc export "$name" "$backup_path" --compression gzip 2>&1 | tee -a "$LOG_FILE"; then
        local size=$(du -h "$backup_path" | cut -f1)
        log_success "Backup created: $backup_name.tar.gz ($size)"
        return 0
    else
        log_error "Backup failed"
        return 1
    fi
}

restore_container() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        # List available backups
        echo -e "${CYAN}Available backups:${NC}"
        ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | xargs -n1 basename
        
        echo -e "\n${CYAN}Backup file:${NC}"
        read -p "  Filename: " backup_file
    fi
    
    if [ -z "$backup_file" ]; then
        log_error "No backup file provided"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_file"
    
    if [ ! -f "$backup_path" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Container name
    local container_name=$(basename "$backup_file" .tar.gz | sed 's/_backup_.*//')
    local new_name="${container_name}_restored_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${CYAN}New container name:${NC}"
    read -p "  (default: $new_name): " input_name
    new_name=${input_name:-$new_name}
    
    print_section "RESTORE CONTAINER"
    
    log_info "Restoring '$backup_file' to '$new_name'..."
    
    if lxc import "$backup_path" "$new_name" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Container restored as '$new_name'"
        
        # Start container
        echo -e "\n${YELLOW}Start container? (y/n):${NC}"
        read -r start_choice
        if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
            lxc start "$new_name"
            log_success "Container started"
        fi
        
        return 0
    else
        log_error "Restore failed"
        return 1
    fi
}

# =====================================================================
# SYSTEM MONITORING
# =====================================================================

monitor_system() {
    print_section "SYSTEM MONITOR"
    
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring...${NC}"
    echo ""
    
    while true; do
        clear
        print_section "SYSTEM MONITOR"
        
        # Host stats
        echo -e "${GREEN}🏠 HOST SYSTEM${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
        
        # CPU
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'.' -f1)
        echo -e "  CPU: ${cpu_usage}%"
        
        # Memory
        local mem_total=$(free -m | awk 'NR==2{print $2}')
        local mem_used=$(free -m | awk 'NR==2{print $3}')
        local mem_percent=$((mem_used * 100 / mem_total))
        echo -e "  Memory: ${mem_used}MB/${mem_total}MB (${mem_percent}%)"
        
        # Disk
        local disk_usage=$(df -h / | awk 'NR==2{print $5}')
        echo -e "  Disk: $disk_usage used"
        
        # Container stats
        echo -e "\n${GREEN}🐳 CONTAINERS${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
        
        local containers=$(lxc list --format csv 2>/dev/null | head -5)
        if [ -n "$containers" ]; then
            echo "$containers" | while IFS=',' read -r name status ip type arch; do
                echo -e "  $name: $status ($ip)"
            done
        else
            echo "  No containers found"
        fi
        
        # System info
        echo -e "\n${GREEN}📊 SYSTEM INFO${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
        echo -e "  Time: $(date '+%H:%M:%S')"
        echo -e "  Uptime: $(uptime -p | sed 's/up //')"
        echo -e "  Load: $(uptime | awk -F'load average:' '{print $2}')"
        
        # Alerts
        echo -e "\n${GREEN}🚨 ALERTS${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
        
        if [ $cpu_usage -gt 80 ]; then
            echo -e "  ⚠️  High CPU usage: ${cpu_usage}%"
        fi
        
        if [ $mem_percent -gt 80 ]; then
            echo -e "  ⚠️  High Memory usage: ${mem_percent}%"
        fi
        
        echo -e "\n${YELLOW}Refreshing in 3 seconds...${NC}"
        sleep 3
    done
}

# =====================================================================
# ADVANCED TOOLS
# =====================================================================

clone_container() {
    local source=$1
    
    if [ -z "$source" ]; then
        echo -e "${CYAN}Source container:${NC}"
        read -p "  Name: " source
    fi
    
    if [ -z "$source" ]; then
        log_error "No source container provided"
        return 1
    fi
    
    # Clone name
    local clone_name="${source}_clone_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${CYAN}Clone name:${NC}"
    read -p "  (default: $clone_name): " input_name
    clone_name=${input_name:-$clone_name}
    
    print_section "CLONE CONTAINER"
    
    log_info "Cloning '$source' to '$clone_name'..."
    
    if lxc copy "$source" "$clone_name" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Container cloned as '$clone_name'"
        
        # Start clone
        echo -e "\n${YELLOW}Start cloned container? (y/n):${NC}"
        read -r start_choice
        if [[ "$start_choice" == "y" || "$start_choice" == "Y" ]]; then
            lxc start "$clone_name"
            log_success "Clone started"
        fi
        
        return 0
    else
        log_error "Clone failed"
        return 1
    fi
}

snapshot_container() {
    local name=$1
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Container name:${NC}"
        read -p "  Name: " name
    fi
    
    if [ -z "$name" ]; then
        log_error "No container name provided"
        return 1
    fi
    
    # Snapshot name
    local snapshot_name="snap_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${CYAN}Snapshot name:${NC}"
    read -p "  (default: $snapshot_name): " input_name
    snapshot_name=${input_name:-$snapshot_name}
    
    print_section "CREATE SNAPSHOT"
    
    log_info "Creating snapshot '$snapshot_name' for '$name'..."
    
    if lxc snapshot "$name" "$snapshot_name" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Snapshot created: $snapshot_name"
        return 0
    else
        log_error "Snapshot failed"
        return 1
    fi
}

cleanup_system() {
    print_section "SYSTEM CLEANUP"
    
    echo -e "${YELLOW}Select cleanup option:${NC}"
    echo "  1. Remove stopped containers"
    echo "  2. Remove unused images"
    echo "  3. Clear old backups (older than 7 days)"
    echo "  4. Clear cache and logs"
    echo "  5. Full cleanup"
    echo "  6. Cancel"
    
    read -p "Select (1-6): " choice
    
    case $choice in
        1)
            log_info "Removing stopped containers..."
            lxc list --format csv | grep "STOPPED" | cut -d',' -f1 | xargs -r lxc delete
            log_success "Stopped containers removed"
            ;;
        2)
            log_info "Removing unused images..."
            lxc image list --format csv | grep -v "|CURRENT" | cut -d'|' -f2 | xargs -r lxc image delete
            log_success "Unused images removed"
            ;;
        3)
            log_info "Clearing old backups..."
            find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
            log_success "Old backups cleared"
            ;;
        4)
            log_info "Clearing cache and logs..."
            rm -f "$CACHE_FILE"
            echo "" > "$LOG_FILE"
            log_success "Cache and logs cleared"
            ;;
        5)
            echo -e "${RED}⚠️  WARNING: This will perform full cleanup!${NC}"
            read -p "Are you sure? (type 'yes' to confirm): " confirm
            if [[ "$confirm" == "yes" ]]; then
                log_info "Performing full cleanup..."
                
                # Stop and remove all containers
                lxc list --format csv | cut -d',' -f1 | xargs -r lxc delete --force
                
                # Remove all images
                lxc image list --format csv | cut -d'|' -f2 | xargs -r lxc image delete
                
                # Clear backups
                rm -rf "$BACKUP_DIR"/*
                
                # Clear cache and logs
                rm -f "$CACHE_FILE"
                echo "" > "$LOG_FILE"
                
                log_success "Full cleanup completed"
            else
                log_info "Cleanup cancelled"
            fi
            ;;
        6)
            log_info "Cleanup cancelled"
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac
}

# =====================================================================
# MAIN MENU
# =====================================================================

show_main_menu() {
    while true; do
        print_header
        
        # System status
        echo -e "${GREEN}📊 SYSTEM STATUS${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
        
        if check_lxc_installation; then
            local container_count=$(lxc list --format csv 2>/dev/null | wc -l)
            local running_count=$(lxc list --format csv 2>/dev/null | grep -c "RUNNING")
            local lxc_version=$(lxc --version 2>/dev/null | head -1)
            
            echo -e "  LXC: ${GREEN}v$lxc_version${NC}"
            echo -e "  Containers: ${GREEN}$running_count running / $container_count total${NC}"
            
            # Quick resource info
            local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'.' -f1)
            local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
            echo -e "  Resources: CPU ${cpu_usage}% | Mem ${mem_usage}%"
        else
            echo -e "  LXC: ${RED}Not Installed${NC}"
            echo -e "  Status: ${YELLOW}Ready for installation${NC}"
        fi
        
        echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
        
        # Menu options
        echo -e "\n${CYAN}📦 CONTAINER MANAGEMENT${NC}"
        echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"
        echo "  1. 🚀 Create new container (Smart)"
        echo "  2. 📋 List all containers"
        echo "  3. ▶️  Start container"
        echo "  4. ⏸️  Stop container"
        echo "  5. 🔄 Restart container"
        echo "  6. ❌ Delete container"
        echo "  7. 💻 Container shell"
        echo "  8. ℹ️  Container info"
        echo "  9. 📊 Live container stats"
        
        echo -e "\n${CYAN}🛠️  ADVANCED TOOLS${NC}"
        echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"
        echo "  10. 💾 Backup container"
        echo "  11. 📥 Restore container"
        echo "  12. 🐑 Clone container"
        echo "  13. 📸 Create snapshot"
        echo "  14. 🗑️  System cleanup"
        echo "  15. 📈 System monitor"
        
        echo -e "\n${CYAN}⚙️  SYSTEM TOOLS${NC}"
        echo -e "${YELLOW}────────────────────────────────────────────────────────────────${NC}"
        echo "  16. 🌐 Fix network issues"
        echo "  17. 🔧 Check & repair LXC"
        echo "  18. 📝 View logs"
        echo "  19. 🆕 Update LXC/LXD"
        echo "  20. 🚪 Exit"
        
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        
        read -p "$(echo -e "${YELLOW}Select option (1-20):${NC} ")" choice
        
        case $choice in
            1) create_container_smart ;;
            2) list_containers ;;
            3) start_container ;;
            4) stop_container ;;
            5) restart_container ;;
            6) delete_container ;;
            7) container_shell ;;
            8) container_info ;;
            9) container_stats ;;
            10) backup_container ;;
            11) restore_container ;;
            12) clone_container ;;
            13) snapshot_container ;;
            14) cleanup_system ;;
            15) monitor_system ;;
            16) fix_network_issues ;;
            17) check_and_repair_lxc ;;
            18) view_logs ;;
            19) update_lxc_lxd ;;
            20) 
                echo -e "\n${GREEN}Thank you for using LXC Manager! 👋${NC}"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# =====================================================================
# ADDITIONAL TOOLS
# =====================================================================

check_and_repair_lxc() {
    print_section "LXC CHECK & REPAIR"
    
    local issues=0
    
    # Check LXC installation
    if ! check_lxc_installation; then
        print_warning "LXC not properly installed"
        echo -e "${YELLOW}Install LXC? (y/n):${NC}"
        read -r install_choice
        if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
            install_lxc
        fi
        issues=$((issues+1))
    fi
    
    # Check LXD initialization
    if ! lxc storage list &>/dev/null; then
        print_warning "LXD not initialized"
        initialize_lxd
        issues=$((issues+1))
    fi
    
    # Check network bridge
    if ! check_network_bridge; then
        print_warning "No network bridge"
        create_default_bridge
        issues=$((issues+1))
    fi
    
    # Check LXD service
    if ! systemctl is-active --quiet lxd; then
        print_warning "LXD service not running"
        sudo systemctl start lxd
        sudo systemctl enable lxd
        issues=$((issues+1))
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "No issues found. LXC is healthy!"
    else
        log_success "Fixed $issues issues"
    fi
}

view_logs() {
    print_section "LOGS VIEWER"
    
    echo -e "${CYAN}Select log to view:${NC}"
    echo "  1. LXC Manager Log"
    echo "  2. LXD Service Log"
    echo "  3. System Messages"
    echo "  4. All logs"
    
    read -p "Select (1-4): " log_choice
    
    case $log_choice in
        1)
            echo -e "\n${YELLOW}LXC Manager Log:${NC}"
            tail -50 "$LOG_FILE"
            ;;
        2)
            echo -e "\n${YELLOW}LXD Service Log:${NC}"
            sudo journalctl -u lxd --no-pager -n 50
            ;;
        3)
            echo -e "\n${YELLOW}System Messages:${NC}"
            sudo dmesg | tail -50
            ;;
        4)
            echo -e "\n${YELLOW}All logs:${NC}"
            tail -50 "$LOG_FILE"
            echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
            sudo journalctl -u lxd --no-pager -n 20
            echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
            sudo dmesg | tail -20
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac
}

update_lxc_lxd() {
    print_section "UPDATE LXC/LXD"
    
    detect_os
    
    echo -e "${YELLOW}Updating LXC/LXD on $OS_NAME...${NC}"
    
    case $OS_ID in
        ubuntu|debian)
            sudo apt update && sudo apt upgrade -y lxc lxc-utils lxd
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf update -y lxc lxc-templates lxd
            else
                sudo yum update -y lxc lxc-templates lxd
            fi
            ;;
        arch)
            sudo pacman -Syu --noconfirm lxc lxd
            ;;
        *)
            log_error "Unsupported OS for auto-update"
            return 1
            ;;
    esac
    
    # If installed via snap
    if snap list | grep -q lxd; then
        sudo snap refresh lxd
    fi
    
    log_success "LXC/LXD updated successfully"
}

# =====================================================================
# INITIALIZATION
# =====================================================================

initialize_system() {
    print_header
    
    # Check if LXC is installed
    if ! check_lxc_installation; then
        echo -e "${YELLOW}LXC/LXD is not installed or not properly configured.${NC}"
        echo ""
        echo "Options:"
        echo "  1. Install LXC automatically (Recommended)"
        echo "  2. Skip for now"
        echo "  3. Exit"
        echo ""
        
        read -p "Select option (1-3): " init_choice
        
        case $init_choice in
            1)
                install_lxc
                initialize_lxd
                ;;
            2)
                log_warning "Skipping installation. Some features may not work."
                ;;
            3)
                exit 0
                ;;
            *)
                install_lxc
                ;;
        esac
    fi
    
    # Check LXD initialization
    if ! lxc storage list &>/dev/null; then
        initialize_lxd
    fi
    
    # Check network
    if ! check_network_bridge; then
        log_warning "No network bridge found"
        create_default_bridge
    fi
    
    log_success "System initialized successfully"
    sleep 2
}

# =====================================================================
# MAIN EXECUTION
# =====================================================================

# Check for command line arguments
case "$1" in
    --install)
        install_lxc
        exit 0
        ;;
    --init)
        initialize_system
        exit 0
        ;;
    --fix-network)
        fix_network_issues
        exit 0
        ;;
    --backup)
        backup_container "$2"
        exit 0
        ;;
    --restore)
        restore_container "$2"
        exit 0
        ;;
    --list)
        list_containers
        exit 0
        ;;
    --monitor)
        monitor_system
        exit 0
        ;;
    --help)
        print_header
        echo -e "${CYAN}Usage:${NC}"
        echo "  ./lxc-manager.sh                 # Interactive menu"
        echo "  ./lxc-manager.sh --install       # Install LXC"
        echo "  ./lxc-manager.sh --init          # Initialize system"
        echo "  ./lxc-manager.sh --fix-network   # Fix network issues"
        echo "  ./lxc-manager.sh --list          # List containers"
        echo "  ./lxc-manager.sh --backup <name> # Backup container"
        echo "  ./lxc-manager.sh --restore <file># Restore container"
        echo "  ./lxc-manager.sh --monitor       # System monitor"
        echo "  ./lxc-manager.sh --help          # Show help"
        exit 0
        ;;
esac

# Main execution
initialize_system
show_main_menu
