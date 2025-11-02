
#!/bin/bash

# (Previous functions remain the same, including all prior content)

# Prepare OmniStream environment configuration
prepare_omnistream_environment() {
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
    fi
}

# Update main function to include new environment preparation
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
# wget -O - https://raw.githubusercontent.com/kelinger/OmniStream4/main/install-omnistream.sh | bash
