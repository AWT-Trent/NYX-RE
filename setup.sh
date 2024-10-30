#!/bin/bash

# Setup Variables
ISO_PATH="/opt/iso/winpe.iso"   # Path to the ISO file
EXTRACT_DIR="/opt/iso/winpe"    # Directory to extract the ISO contents
MAIN_SCRIPT_PATH="/usr/local/bin/usb_writer.sh"  # Path where the main script will be installed
DOWNLOAD_URL_FILE="download_url.txt"  # File holding the download URL
VERSION_FILE="version.txt"  # File holding the ISO version number
ISO_TEMP_PATH="/opt/iso/nyx_temp.iso"  # Temporary path to download the ISO

# Ensure the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Update package lists and install necessary dependencies
echo "Updating package lists..."
sudo apt-get update -y

echo "Installing required packages..."
sudo apt-get install -y util-linux parted dosfstools p7zip-full curl

# Check if 7z is installed correctly
if ! command -v 7z &> /dev/null; then
    echo "Error: 7z command not found. Please install p7zip-full."
    exit 1
fi

# Ensure the /opt/iso directory exists
if [ ! -d "/opt/iso" ]; then
    echo "Creating /opt/iso directory..."
    sudo mkdir -p /opt/iso
fi

# Fix the SharePoint URL format in download_url.txt
if [ -f "$DOWNLOAD_URL_FILE" ]; then
    DOWNLOAD_URL=$(cat "$DOWNLOAD_URL_FILE")
    CLEANED_URL=$(echo "$DOWNLOAD_URL" | sed 's/\?.*/?download=1/')
    echo "Corrected URL: $CLEANED_URL"

    # Download the ISO file
    echo "Downloading the latest ISO..."
    curl -L -o "$ISO_TEMP_PATH" "$CLEANED_URL"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to download the ISO."
        exit 1
    fi

    # Replace the old ISO with the new one
    echo "Replacing the old ISO..."
    sudo mv "$ISO_TEMP_PATH" "$ISO_PATH"
else
    echo "Error: download_url.txt not found."
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
