#!/bin/bash

# OmniStream Installation Script
# Designed EXCLUSIVELY for Debian 13 Linux
# Ensures system readiness and installs required components

# Error handling and logging
set -eE
trap 'handle_error $?' ERR

LOG_FILE="$HOME/omnistream_install.log"
touch "$LOG_FILE"

# Verify Debian Version
verify_debian_version() {
    # Strict checks to ensure Debian 13 (Trixie)
    if [ ! -f /etc/debian_version ]; then
        dialog --title "Unsupported Operating System" --msgbox "Error: This script requires PURE Debian Linux. Your system is not Debian." 10 50
        exit 1
    fi

    # Extract Debian version details
    DEBIAN_VERSION=$(cat /etc/debian_version)
    DEBIAN_CODENAME=$(grep -Po 'VERSION_CODENAME=\K[^"]+' /etc/os-release)
    OS_ID=$(grep -Po 'ID=\K[^"]+' /etc/os-release)

    # Strict checks
    if [[ "$OS_ID" != "debian" ]]; then
        dialog --title "Invalid Distribution" --msgbox "Error: This script is ONLY for Debian. 
Detected: $OS_ID
This is not a pure Debian distribution." 12 50
        exit 1
    fi

    # Specific check for Debian 13 (Trixie)
    if [[ "$DEBIAN_CODENAME" != "trixie" ]]; then
        dialog --title "Unsupported Debian Version" --msgbox "Error: OmniStream REQUIRES Debian 13 (Trixie). 
Current version: $DEBIAN_CODENAME ($DEBIAN_VERSION)
You must use Debian 13 Trixie EXACTLY." 12 50
        exit 1
    fi
}

# Dependency check and installation
check_and_install_dependencies() {
    # Ensure dialog and sudo are available
    if ! command -v dialog &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y dialog
    fi

    if ! command -v sudo &> /dev/null; then
        su - root -c "apt-get update && apt-get install -y sudo"
    fi
}

# Error handling function
handle_error() {
    dialog --title "Installation Error" --msgbox "An error occurred during installation (Exit code: $1). Please check $LOG_FILE for details." 10 50
    exit 1
}

# System update and package installation function
prepare_system_components() {
    local packages=(
        acl apache2-utils apt-transport-https at bc ca-certificates
        curl dialog dnsutils git-core htop jq keychain net-tools
        parallel pigz pipx pv rsync speedometer speedtest-cli
        sqlite3 tmux unzip vnstat wget
    )

    # Progress dialog with detailed tracking
    {
        echo "10" ; echo "Updating package lists..."
        sudo apt-get update -qq 2>> "$LOG_FILE"

        # Install packages with individual tracking
        total=${#packages[@]}
        for i in "${!packages[@]}"; do
            pkg="${packages[i]}"
            progress=$((10 + (i * 80 / total)))
            
            # Check and install individual package
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
            fi
            
            echo "$progress" 
        done

        # Final steps
        echo "90" ; echo "Upgrading system packages..."
        sudo apt-get upgrade -y >> "$LOG_FILE" 2>&1
        sudo apt-get autoremove -y >> "$LOG_FILE" 2>&1

        echo "100"
    } | dialog --title "System Preparation" --gauge "Preparing system components..." 10 50 0

    # Ensure cursor is at the bottom of the screen
    echo
}

# Docker and Docker Compose installation
install_docker() {
    # Progress dialog for Docker installation
    {
        echo "0" ; sleep 0.5
        
        echo "20" ; echo "Preparing Docker installation..." 
        sudo apt-get update -qq >> "$LOG_FILE" 2>&1
        
        echo "40" ; echo "Installing required certificates..."
        sudo apt-get install -y ca-certificates curl gnupg >> "$LOG_FILE" 2>&1
        
        echo "60" ; echo "Setting up Docker repository..."
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo "80" ; echo "Configuring Docker repository..."
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update -qq >> "$LOG_FILE" 2>&1
        
        echo "90" ; echo "Installing Docker components..."
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1
        
        # Add current user to docker group
        sudo usermod -aG docker "$USER" >> "$LOG_FILE" 2>&1
        
        echo "100"
    } | dialog --title "Docker Installation" --gauge "Installing Docker and Docker Compose..." 10 50 0

    # Ensure cursor is at the bottom of the screen
    echo
}

# Clone OmniStream project
clone_omnistream_project() {
    # Define the project repository (replace with actual repository URL)
    REPO_URL="https://github.com/kelinger/OmniStream4.git"
    INSTALL_DIR="$HOME/omnistream"

    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Progress dialog for project cloning
    {
        echo "0" ; sleep 0.5
        
        echo "30" ; echo "Preparing to clone OmniStream repository..."
        
        echo "60" ; echo "Cloning project from repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
        
        echo "90" ; echo "Setting up project directory..."
        cd "$INSTALL_DIR"
        
        echo "100"
    } | dialog --title "OmniStream Project" --gauge "Downloading OmniStream project..." 10 50 0

    # Verify successful clone
    if [ -d "$INSTALL_DIR/.git" ]; then
        dialog --title "Project Clone" --msgbox "OmniStream project successfully cloned to $INSTALL_DIR" 10 50
    else
        dialog --title "Clone Error" --msgbox "Failed to clone OmniStream project. Please check the repository URL." 10 50
        exit 1
    fi
}

# Prepare OmniStream project directories and user configuration
prepare_omnistream_environment() {
    # Define directories to create
    local dirs=(
        "${HOME}/omnistream/configs"
        "${HOME}/omnistream/enabled"
        "${HOME}/omnistream/logs"
    )

    # Create directories if they don't exist
    for dir in "${dirs[@]}"; do
        if [ ! -d "${dir}" ]; then
            mkdir -p "${dir}"
            dialog --title "Directory Creation" --msgbox "Created directory: ${dir}" 10 50
        fi
    done

    # Modify user's .bashrc to add OmniStream bin to PATH and run omni_init
    # First, ensure the modifications are not already present
    if ! grep -q "OmniStream Configuration" "${HOME}/.bashrc"; then
        {
            echo ""
            echo "# OmniStream Configuration"
            echo "# Add OmniStream bin to PATH"
            echo "export PATH=\"${HOME}/omnistream/bin:${PATH}\""
            echo ""
            echo "# Run OmniStream initialization script"
            echo "if [ -x \"${HOME}/omnistream/bin/omni_init\" ]; then"
            echo "    \"${HOME}/omnistream/bin/omni_init\""
            echo "fi"
        } >> "${HOME}/.bashrc"

        dialog --title "User Configuration" --msgbox "Updated .bashrc to include OmniStream configuration" 10 50
    fi
}

# Main installation process
main() {
    # Clear screen
    clear

    # Check and install core dependencies
    check_and_install_dependencies

    # Verify Debian version
    verify_debian_version

    # Welcome dialog
    dialog --title "OmniStream Installation" --msgbox "Welcome to the OmniStream Installation Script for Debian 13" 10 50

    # Prepare system components
    prepare_system_components

    # Install Docker
    install_docker

    # Clone OmniStream project
    clone_omnistream_project

    # Prepare OmniStream environment
    prepare_omnistream_environment

    # Completion dialog
    dialog --title "Installation Complete" --msgbox "OmniStream system preparation is complete! 
Project cloned to ${HOME}/omnistream
Environment configured for OmniStream" 12 50

    # Ensure cursor is at the bottom of the screen
    echo
}

# Execute main function
main

# One-line download and execution command:
# curl -sSL https://raw.githubusercontent.com/[your-repo]/omnistream-install.sh | bash
