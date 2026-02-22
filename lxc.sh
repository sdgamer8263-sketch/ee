#!/bin/bash

# ============================================
# LXC/LXD Container Manager
# Version: 3.0 - Auto Image Detection
# ============================================


# if you use Ubuntu


# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print header
print_header() {
    clear
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║            LXC/LXD Container Manager                 ║"
    echo "║               Mode BY - SDGAMER                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo
}

# Default image database (fallback)
declare -A DEFAULT_IMAGES=(
    ["1"]="ubuntu:22.04|Ubuntu 22.04 Jammy"
    ["2"]="almalinux/9|AlmaLinux 9"
    ["3"]="centos/stream-9|CentOS Stream 9"
    ["4"]="ubuntu:24.04|Ubuntu 24.04 Noble"
    ["5"]="rockylinux/9|Rocky Linux 9"
    ["6"]="fedora/40|Fedora 40"
    ["7"]="debian/11|Debian 11 Bullseye"
    ["8"]="debian/trixie-daily|Debian 13 Trixie"
    ["9"]="debian/12|Debian 12 Bookworm"
)

# Function to install dependencies
install_dependencies() {
    print_header
    print_color "$CYAN" "🔧 Installing Dependencies..."
    echo "══════════════════════════════════════════════════════"
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$ID
    else
        print_color "$RED" "❌ Cannot detect OS distribution!"
        exit 1
    fi
    
    print_color "$BLUE" "📊 Detected: $PRETTY_NAME"
    echo
    
    case $OS_NAME in
        ubuntu|debian)
            print_color "$GREEN" "📦 Installing for Ubuntu/Debian..."
            echo
            
            # Update package lists
            print_color "$CYAN" "🔄 Updating package lists..."
            sudo apt update -y
            
            # Install LXC
            print_color "$CYAN" "📥 Installing LXC..."
            sudo apt install -y lxc lxc-utils lxc-templates bridge-utils uidmap
            
            # Install and configure snapd for LXD
            if ! command -v snap &> /dev/null; then
                print_color "$CYAN" "📦 Installing snapd..."
                sudo apt install -y snapd
                sudo systemctl enable --now snapd.socket
                sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
                echo "⚠️  Please log out and log back in for snap to work properly"
            fi
            
            # Install LXD
            print_color "$CYAN" "🚀 Installing LXD..."
            sudo snap install lxd
            
            # Add user to lxd group
            print_color "$CYAN" "👤 Adding user to lxd group..."
            sudo usermod -aG lxd $USER
            
            # Initialize LXD
            print_color "$CYAN" "⚙️  Initializing LXD..."
            echo "This will set up LXD with default settings..."
            sudo lxd init --auto
            
            # Start LXD service
            print_color "$CYAN" "▶️  Starting LXD service..."
            sudo systemctl start snap.lxd.daemon 2>/dev/null || sudo systemctl start lxd 2>/dev/null
            
            print_color "$GREEN" "✅ Dependencies installed successfully!"
            echo
            print_color "$YELLOW" "⚠️  IMPORTANT: Please log out and log back in for group changes!"
            print_color "$YELLOW" "   Then run this script again."
            ;;
        *)
            print_color "$RED" "❌ Unsupported OS: $OS_NAME"
            print_color "$YELLOW" "📋 Manual installation required:"
            echo "For Ubuntu/Debian:"
            echo "  sudo apt install lxc lxc-utils bridge-utils snapd"
            echo "  sudo snap install lxd"
            echo "  sudo usermod -aG lxd \$USER"
            echo "  sudo lxd init --auto"
            ;;
    esac
    
    read -p "⏎ Press Enter to continue..."
    exit 0
}

# Function to check installation
check_installation() {
    print_header
    print_color "$CYAN" "🔍 Checking Installation..."
    echo "══════════════════════════════════════════════════════"
    echo
    
    local checks_passed=0
    local total_checks=5
    
    # Check LXC
    if command -v lxc &> /dev/null; then
        print_color "$GREEN" "✅ LXC is installed"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXC is NOT installed"
    fi
    
    # Check LXD
    if command -v lxd &> /dev/null; then
        print_color "$GREEN" "✅ LXD is installed"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXD is NOT installed"
    fi
    
    # Check if user is in lxd group
    if groups $USER | grep -q '\blxd\b'; then
        print_color "$GREEN" "✅ User is in lxd group"
        ((checks_passed++))
    else
        print_color "$YELLOW" "⚠️  User is NOT in lxd group"
    fi
    
    # Check LXD service
    if systemctl is-active --quiet snap.lxd.daemon 2>/dev/null || systemctl is-active --quiet lxd 2>/dev/null; then
        print_color "$GREEN" "✅ LXD service is running"
        ((checks_passed++))
    else
        print_color "$RED" "❌ LXD service is NOT running"
    fi
    
    # Check if LXD is initialized
    if lxc cluster list 2>&1 | grep -q "no such file or directory" || lxc cluster list 2>&1 | grep -q "not initialized"; then
        print_color "$YELLOW" "⚠️  LXD is not initialized"
    else
        print_color "$GREEN" "✅ LXD is initialized"
        ((checks_passed++))
    fi
    
    echo
    print_color "$BLUE" "📊 Status: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        print_color "$GREEN" "🎉 All systems go! LXC/LXD is ready."
    elif [[ $checks_passed -ge 3 ]]; then
        print_color "$YELLOW" "⚠️  Some issues detected. Check below:"
        echo
        print_color "$CYAN" "💡 Troubleshooting tips:"
        echo "1. If not in lxd group, run: sudo usermod -aG lxd $USER"
        echo "2. If LXD not initialized, run: sudo lxd init --auto"
        echo "3. If service not running: sudo systemctl start snap.lxd.daemon"
        echo "4. Log out and log back in after adding to lxd group"
    else
        print_color "$RED" "🚨 Major issues detected. Please reinstall dependencies."
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to detect available images
detect_available_images() {
    print_color "$CYAN" "🔍 Scanning for available images..."
    echo
    
    # Clear previous image list
    declare -gA AVAILABLE_IMAGES
    AVAILABLE_IMAGES=()
    
    # List of remotes to check
    local remotes=("images" "ubuntu" "debian" "fedora" "centos" "almalinux" "rockylinux")
    local image_count=0
    
    # Try to get images from remotes
    for remote in "${remotes[@]}"; do
        print_color "$BLUE" "📡 Checking remote: $remote"
        
        # Try to list images from this remote
        local remote_images=$(timeout 10 lxc image list "$remote:" 2>/dev/null | grep -E "^\| [a-zA-Z0-9/:-]+ \|" | head -20)
        
        if [[ -n "$remote_images" ]]; then
            while IFS= read -r line; do
                # Extract image name from line
                local image_name=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
                local description=$(echo "$line" | awk -F'|' '{print $3}' | xargs | cut -c1-50)
                
                if [[ -n "$image_name" && ! "$image_name" =~ "ALIAS" && ! "$image_name" =~ "FINGERPRINT" ]]; then
                    ((image_count++))
                    AVAILABLE_IMAGES["$image_count"]="$remote:$image_name|$description"
                    echo "  ✅ Found: $remote:$image_name"
                fi
            done <<< "$remote_images"
        else
            echo "  ⚠️  No images found or remote not accessible"
        fi
    done
    
    # If no images found, use defaults
    if [[ ${#AVAILABLE_IMAGES[@]} -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  Could not detect images automatically. Using defaults..."
        AVAILABLE_IMAGES=("${DEFAULT_IMAGES[@]}")
        for key in "${!DEFAULT_IMAGES[@]}"; do
            AVAILABLE_IMAGES["$key"]="${DEFAULT_IMAGES[$key]}"
        done
    fi
    
    echo
    print_color "$GREEN" "✅ Found ${#AVAILABLE_IMAGES[@]} available images"
    sleep 1
}

# Function to show image selection menu
show_image_menu() {
    print_header
    print_color "$CYAN" "📦 Available Container Images"
    echo "══════════════════════════════════════════════════════"
    echo
    
    # Sort image keys numerically
    mapfile -t sorted_keys < <(printf '%s\n' "${!AVAILABLE_IMAGES[@]}" | sort -n)
    
    for key in "${sorted_keys[@]}"; do
        IFS='|' read -r image_name display_name <<< "${AVAILABLE_IMAGES[$key]}"
        print_color "$GREEN" "  $key) $display_name"
        print_color "$BLUE" "     📦 Image: $image_name"
        echo
    done
    
    echo "══════════════════════════════════════════════════════"
    echo "  0) ↩️  Back to Main Menu"
    echo "  r) 🔄 Refresh Image List"
    echo
}

# Function to search for specific images
search_images() {
    print_header
    print_color "$CYAN" "🔍 Search Images"
    echo "══════════════════════════════════════════════════════"
    echo
    
    read -p "🔎 Enter search term (e.g., ubuntu, debian, centos): " search_term
    
    if [[ -z "$search_term" ]]; then
        return
    fi
    
    print_color "$BLUE" "🔍 Searching for '$search_term'..."
    echo
    
    local search_results=()
    local result_count=0
    
    # Search in available images
    for key in "${!AVAILABLE_IMAGES[@]}"; do
        IFS='|' read -r image_name display_name <<< "${AVAILABLE_IMAGES[$key]}"
        if [[ "$image_name" =~ $search_term || "$display_name" =~ $search_term ]]; then
            ((result_count++))
            search_results["$result_count"]="$image_name|$display_name"
            print_color "$GREEN" "  $result_count) $display_name"
            print_color "$BLUE" "     📦 Image: $image_name"
            echo
        fi
    done
    
    if [[ $result_count -eq 0 ]]; then
        print_color "$YELLOW" "⚠️  No images found matching '$search_term'"
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to create container from selected image
create_container() {
    # Detect available images first
    detect_available_images
    
    while true; do
        show_image_menu
        read -p "🎯 Select image (1-${#AVAILABLE_IMAGES[@]}) or 0/r: " image_choice
        
        case $image_choice in
            0)
                return
                ;;
            r|R)
                detect_available_images
                continue
                ;;
        esac
        
        if [[ -n "${AVAILABLE_IMAGES[$image_choice]}" ]]; then
            IFS='|' read -r image_name display_name <<< "${AVAILABLE_IMAGES[$image_choice]}"
            break
        else
            print_color "$RED" "❌ Invalid selection!"
            sleep 2
        fi
    done
    
    print_header
    print_color "$CYAN" "🚀 Creating Container: $display_name"
    print_color "$BLUE" "📦 Image: $image_name"
    echo "══════════════════════════════════════════════════════"
    echo
    
    # Get container name
    while true; do
        read -p "🏷️  Enter container name: " container_name
        
        # Check if empty
        if [[ -z "$container_name" ]]; then
            print_color "$RED" "❌ Container name cannot be empty!"
            continue
        fi
        
        # Validate name format
        if [[ ! "$container_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]{1,}$ ]]; then
            print_color "$RED" "❌ Invalid name! Must start with letter, can contain letters, numbers, hyphens, underscores"
            continue
        fi
        
        # Check if container already exists
        if lxc list -c n --format csv 2>/dev/null | grep -q "^$container_name$"; then
            print_color "$RED" "❌ Container '$container_name' already exists!"
            
            read -p "🔄 Use different name? (y/N): " rename_choice
            if [[ ! "$rename_choice" =~ ^[Yy]$ ]]; then
                return
            fi
            continue
        fi
        
        break
    done
    
    # Get container type
    echo
    print_color "$YELLOW" "💻 Container Type:"
    echo "  1) Container (Default) - Lightweight, shares host kernel"
    echo "  2) Virtual Machine - Full VM with its own kernel (more resources)"
    read -p "Select type (1-2, default: 1): " container_type
    container_type=${container_type:-1}
    
    local type_flag=""
    case $container_type in
        1) 
            type_flag=""
            print_color "$BLUE" "📦 Selected: Container (lightweight)"
            ;;
        2) 
            type_flag="--vm"
            print_color "$BLUE" "💻 Selected: Virtual Machine"
            ;;
        *) 
            type_flag=""
            print_color "$YELLOW" "⚠️  Using default: Container"
            ;;
    esac
    
    # Get resources
    echo
    print_color "$YELLOW" "⚙️  Resource Configuration:"
    read -p "💾 Disk size (e.g., 10GB, default: 10GB): " disk_size
    disk_size=${disk_size:-10GB}
    
    read -p "🧠 Memory (e.g., 2GB, default: 2GB): " memory
    memory=${memory:-2GB}
    
    read -p "⚡ CPU cores (default: 2): " cpu_count
    cpu_count=${cpu_count:-2}
    
    # Summary
    echo
    print_color "$CYAN" "📋 Creation Summary:"
    echo "──────────────────────────────────────"
    echo "🏷️  Name: $container_name"
    echo "📦 Image: $image_name"
    echo "💻 Type: $([ "$type_flag" == "--vm" ] && echo "Virtual Machine" || echo "Container")"
    echo "💾 Disk: $disk_size"
    echo "🧠 Memory: $memory"
    echo "⚡ CPU: $cpu_count cores"
    echo "──────────────────────────────────────"
    echo
    
    read -p "✅ Proceed with creation? (Y/n): " confirm
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "⚠️  Creation cancelled."
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Create container
    print_color "$BLUE" "📦 Creating container '$container_name'..."
    echo
    
    # Try different approaches to launch container
    local launch_success=false
    
    # Approach 1: Direct launch
    print_color "$CYAN" "🔄 Attempt 1: Direct launch..."
    if lxc launch $type_flag "$image_name" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
        launch_success=true
    else
        # Check error
        local error_msg=$(cat /tmp/lxc_launch.log)
        
        # Approach 2: Try with images: prefix
        if [[ "$error_msg" == *"not found"* ]] || [[ "$error_msg" == *"couldn't be found"* ]]; then
            print_color "$YELLOW" "🔄 Attempt 2: Trying with 'images:' prefix..."
            
            if [[ ! "$image_name" =~ ^images: ]]; then
                local image_with_prefix="images:$image_name"
                if lxc launch $type_flag "$image_with_prefix" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
                    launch_success=true
                fi
            fi
        fi
        
        # Approach 3: Try to find similar image
        if [[ "$launch_success" == false ]]; then
            print_color "$YELLOW" "🔄 Attempt 3: Searching for similar image..."
            
            # Extract base name
            local base_name=$(echo "$image_name" | awk -F'/' '{print $NF}' | awk -F':' '{print $1}')
            
            # Search in available remotes
            for remote in "images" "ubuntu" "debian"; do
                print_color "$BLUE" "   Searching in remote: $remote"
                local found_image=$(lxc image list "$remote:" 2>/dev/null | grep -i "$base_name" | head -1 | awk -F'|' '{print $2}' | xargs)
                
                if [[ -n "$found_image" ]]; then
                    print_color "$GREEN" "   ✅ Found: $remote:$found_image"
                    if lxc launch $type_flag "$remote:$found_image" "$container_name" 2>&1 | tee /tmp/lxc_launch.log; then
                        launch_success=true
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [[ "$launch_success" == false ]]; then
        print_color "$RED" "❌ Failed to create container!"
        echo
        print_color "$YELLOW" "💡 Troubleshooting tips:"
        echo "1. Check if LXD is initialized: sudo lxd init --auto"
        echo "2. List available images: lxc image list images:"
        echo "3. Try a different image name"
        echo "4. Check internet connection"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # Set resource limits
    print_color "$BLUE" "⚙️  Configuring resources..."
    
    # Set CPU
    if lxc config set "$container_name" limits.cpu="$cpu_count" 2>/dev/null; then
        print_color "$GREEN" "✅ CPU set to: $cpu_count cores"
    else
        print_color "$YELLOW" "⚠️  Could not set CPU limit"
    fi
    
    # Set Memory
    if lxc config set "$container_name" limits.memory="$memory" 2>/dev/null; then
        print_color "$GREEN" "✅ Memory set to: $memory"
    else
        print_color "$YELLOW" "⚠️  Could not set memory limit"
    fi
    
    # Wait for container to be ready
    print_color "$BLUE" "⏳ Waiting for container to initialize..."
    sleep 8
    
    # Show container info
    echo
    print_color "$CYAN" "📊 Container Information:"
    echo "──────────────────────────────────────"
    lxc list "$container_name"
    
    # Get IP address
    local container_ip=$(lxc list "$container_name" -c 4 --format csv | head -1)
    
    echo
    print_color "$GREEN" "🎉 Container '$container_name' created successfully!"
    
    if [[ -n "$container_ip" && "$container_ip" != "-" ]]; then
        print_color "$BLUE" "🌐 IP Address: $container_ip"
        
        # Show connection info
        echo
        print_color "$YELLOW" "🔗 Connection Information:"
        
        # Determine OS type for default username
        local default_user=""
        if [[ "$image_name" =~ ubuntu ]]; then
            default_user="ubuntu"
        elif [[ "$image_name" =~ debian ]]; then
            default_user="debian"
        elif [[ "$image_name" =~ centos|rocky|alma|fedora ]]; then
            default_user="root"
        fi
        
        if [[ -n "$default_user" ]]; then
            echo "  SSH: ssh $default_user@$container_ip"
            echo "  Username: $default_user"
            
            if [[ "$default_user" == "root" ]]; then
                echo "  Password: Set during first boot or use SSH keys"
            else
                echo "  Password: No password by default (use SSH keys)"
            fi
        fi
    fi
    
    # Offer to start shell
    echo
    read -p "💻 Open shell in container? (y/N): " open_shell
    if [[ "$open_shell" =~ ^[Yy]$ ]]; then
        echo "📝 Type 'exit' to return to menu"
        lxc exec "$container_name" -- /bin/bash || lxc exec "$container_name" -- /bin/sh
    fi
    
    read -p "⏎ Press Enter to continue..."
}

# Function to list containers
list_containers() {
    print_header
    print_color "$CYAN" "📋 Container List"
    echo "══════════════════════════════════════════════════════"
    echo
    
    if ! command -v lxc &> /dev/null; then
        print_color "$RED" "❌ LXC is not installed!"
        read -p "⏎ Press Enter to continue..."
        return
    fi
    
    # List all containers with formatting
    if ! lxc list; then
        print_color "$YELLOW" "⚠️  Could not list containers. Is LXD running?"
        echo "Try: sudo systemctl start snap.lxd.daemon"
    fi
    
    echo
    print_color "$YELLOW" "📊 Legend:"
    echo "  🟢 RUNNING - Container is active"
    echo "  🔴 STOPPED - Container is not running"
    echo "  ⚪ FROZEN  - Container is paused"
    echo "  🟡 ERROR   - Container has issues"
  
