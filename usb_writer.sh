#!/bin/bash

# Variables
REPO_URL="https://github.com/AWT-Trent/NYX-RE.git"
CLONE_DIR="/opt/nyx-re"
SETUP_SCRIPT="$CLONE_DIR/setup.sh"
LOCAL_VERSION_FILE="/opt/iso/version.txt"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/AWT-Trent/NYX-RE/main/version.txt"

# Function to update from GitHub
function update_and_run_setup() {
    echo "Checking for updates..."

    # Fetch the latest version from GitHub
    REMOTE_VERSION=$(curl -s "$REMOTE_VERSION_URL")

    # Check if the local version file exists
    if [ -f "$LOCAL_VERSION_FILE" ]; then
        LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE")
    else
        LOCAL_VERSION="none"
    fi

    # Compare versions
    if [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
        echo "New version detected: $REMOTE_VERSION. Updating scripts..."

        # Clone the repository
        if [ -d "$CLONE_DIR" ]; then
            sudo rm -rf "$CLONE_DIR"
        fi
        git clone "$REPO_URL" "$CLONE_DIR"

        # Run the setup script
        if [ -f "$SETUP_SCRIPT" ]; then
            echo "Running the setup script..."
            sudo bash "$SETUP_SCRIPT"
        else
            echo "Error: Setup script not found."
            exit 1
        fi

        # After setup, terminate the current script and reboot
        echo "Update complete. Rebooting the system..."
        sudo reboot
    else
        echo "You already have the latest version."
    fi
}

# Main script logic
echo "Starting USB writer..."

# Call the update check and setup
update_and_run_setup

# If no update was found, continue with the rest of the script
echo "No update needed, proceeding with USB writing process..."

# Add your existing USB writing logic here

