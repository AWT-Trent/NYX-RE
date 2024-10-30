#!/bin/bash

# Variables
REPO_URL="https://github.com/AWT-Trent/NYX-RE.git"  # GitHub repository URL
CLONE_DIR="/tmp/nyx-re-clone"  # Temporary directory to clone the repository
SETUP_SCRIPT_PATH="/tmp/nyx-re-clone/setup.sh"  # Path to the setup script after recloning
CURRENT_VERSION_FILE="/opt/iso/version.txt"  # Current version file path
USB_MOUNT_POINT="/mnt/usb"  # Temporary mount point for USB

# Ensure the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Function to check for new version and rerun setup
check_for_update() {
    echo "Checking for updates..."

    # Clone the latest repository
    if [ -d "$CLONE_DIR" ]; then
        echo "Removing old cloned repository..."
        sudo rm -rf "$CLONE_DIR"
    fi

    echo "Cloning the latest repository from GitHub..."
    git clone "$REPO_URL" "$CLONE_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone the repository."
        exit 1
    fi

    # Compare versions
    NEW_VERSION_FILE="$CLONE_DIR/version.txt"
    if [ ! -f "$NEW_VERSION_FILE" ]; then
        echo "Error: New version.txt file not found in cloned repository."
        exit 1
    fi

    if [ -f "$CURRENT_VERSION_FILE" ]; then
        CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
        NEW_VERSION=$(cat "$NEW_VERSION_FILE")

        if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
            echo "New version detected: $NEW_VERSION (Current version: $CURRENT_VERSION)"
            echo "Running setup to update to the latest version..."
            sudo bash "$SETUP_SCRIPT_PATH"
            echo "Update complete. Rebooting..."
            sudo reboot
        else
            echo "No updates found. Continuing with the current version."
        fi
    else
        echo "Current version.txt file not found. Running initial setup..."
        sudo bash "$SETUP_SCRIPT_PATH"
        echo "Setup complete. Rebooting..."
        sudo reboot
    fi
}

# Function to detect and handle USB drives
process_usb() {
    # Detect all connected block devices (excluding the system drive)
    for device in $(lsblk -rno NAME,TYPE | grep "disk" | awk '{print "/dev/"$1}'); do
        # Avoid touching system drive
        if mount | grep -q "$device"; then
            echo "Skipping system drive: $device"
            continue
        fi

        echo "USB drive detected: $device"

        # Unmount and format the USB drive
        sudo umount "$device"* &> /dev/null
        echo "Preparing USB drive: $device"
        sudo mkfs.vfat -F32 "$device" || { echo "Failed to format $device"; continue; }

        echo "USB drive $device is ready."
        echo "Copying files from /opt/iso/winpe to the USB drive..."
        sudo mkdir -p "$USB_MOUNT_POINT"
        sudo mount "$device" "$USB_MOUNT_POINT"
        sudo cp -r /opt/iso/winpe/* "$USB_MOUNT_POINT"
        sudo sync
        sudo umount "$USB_MOUNT_POINT"
        echo "Files copied to USB drive $device successfully."
    done
}

# Check for updates before proceeding
check_for_update

# Proceed with USB processing
process_usb
