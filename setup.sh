#!/bin/bash

# Setup Variables
ISO_PATH="/opt/iso/winpe.iso"   # Path to the ISO file
EXTRACT_DIR="/opt/iso/winpe"    # Directory to extract the ISO contents
MAIN_SCRIPT_PATH="/usr/local/bin/usb_writer.sh"  # Path where the main script will be installed

# Ensure the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Update package lists and install necessary dependencies
echo "Updating package lists..."
sudo apt-get update -y

echo "Installing required packages..."
sudo apt-get install -y util-linux parted dosfstools p7zip-full

# Check if 7z is installed correctly
if ! command -v 7z &> /dev/null; then
    echo "Error: 7z command not found. Please install p7zip-full."
    exit 1
fi

# Create necessary directories
if [ ! -d "/opt/iso" ]; then
    echo "Creating /opt/iso directory..."
    sudo mkdir -p /opt/iso
fi

# Check if the ISO file exists
if [ ! -f "$ISO_PATH" ]; then
    echo "Error: No ISO file found at $ISO_PATH"
    echo "Please place the Windows PE ISO in /opt/iso/ and name it 'winpe.iso'."
    exit 1
fi

# Extract the ISO contents
echo "Extracting ISO contents to $EXTRACT_DIR..."
if [ -d "$EXTRACT_DIR" ]; then
    echo "Removing old extracted files..."
    sudo rm -rf "$EXTRACT_DIR"
fi
sudo mkdir -p "$EXTRACT_DIR"
sudo 7z x "$ISO_PATH" -o"$EXTRACT_DIR"

echo "ISO extraction complete."

# Create the main USB writer script
echo "Creating main script at $MAIN_SCRIPT_PATH..."

cp usb_writer.sh "$MAIN_SCRIPT_PATH"

# Make the script executable
sudo chmod +x "$MAIN_SCRIPT_PATH"

echo "Setup complete! You can now run the script using: sudo $MAIN_SCRIPT_PATH"
