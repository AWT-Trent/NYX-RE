#!/bin/bash

# Setup Variables
REPO_URL="https://github.com/AWT-Trent/NYX-RE.git"  # GitHub repository URL
CLONE_DIR="/tmp/nyx-re-clone"  # Temporary directory to clone the repository
ISO_PATH="/opt/iso/winpe.iso"  # Path to the ISO file
EXTRACT_DIR="/opt/iso/winpe"   # Directory to extract the ISO contents
MAIN_SCRIPT_PATH="/usr/local/bin/usb_writer.sh"  # Path where the main script will be installed
DOWNLOAD_URL_FILE="download_url.txt"  # File holding the download URL
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
sudo apt-get install -y util-linux parted dosfstools p7zip-full git curl

# Check if 7z is installed correctly
if ! command -v 7z &> /dev/null; then
    echo "Error: 7z command not found. Please install p7zip-full."
    exit 1
fi

# Clone the repository to fetch the latest version and download URL
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

# Copy the version.txt and download_url.txt from the cloned repository
VERSION_FILE="$CLONE_DIR/version.txt"
DOWNLOAD_URL_FILE="$CLONE_DIR/download_url.txt"

# Fix the SharePoint URL format in download_url.txt
if [ -f "$DOWNLOAD_URL_FILE" ]; then
    DOWNLOAD_URL=$(cat "$DOWNLOAD_URL_FILE")
    CLEANED_URL=$(echo "$DOWNLOAD_URL" | sed 's/\?.*/?download=1/')
    echo "Corrected URL: $CLEANED_URL"

    # Download the ISO file
    echo "Downloading the latest ISO..."
    wget "$ISO_TEMP_PATH" "$CLEANED_URL"

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
sudo cp "$CLONE_DIR/usb_writer.sh" "$MAIN_SCRIPT_PATH"

# Make the script executable
sudo chmod +x "$MAIN_SCRIPT_PATH"

# Clear the crontab and add a reboot task to start usb_writer.sh
echo "Clearing the crontab..."
crontab -r

echo "Writing crontab entry to start the writer script on reboot..."
(crontab -l 2>/dev/null; echo "@reboot sudo $MAIN_SCRIPT_PATH") | crontab -

echo "Setup complete! You can now run the script using: sudo $MAIN_SCRIPT_PATH"
