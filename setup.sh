#!/bin/bash

# Setup Variables
ISO_PATH="/opt/iso/winpe.iso"   # Path to the ISO file
EXTRACT_DIR="/opt/iso/winpe"    # Directory to extract the ISO contents
MAIN_SCRIPT_PATH="/usr/local/bin/usb_writer.sh"  # Path where the main script will be installed
GIT_REPO="https://github.com/AWT-Trent/NYX-RE.git"  # Git repository URL
VERSION_FILE="/opt/iso/version.txt"
URL_FILE="/opt/iso/download_url.txt"
TEMP_ISO="/opt/iso/nyx_temp.iso"

# Ensure the script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Clear the crontab and add a reboot task to start usb_writer.sh
echo "Clearing the crontab..."
crontab -r

echo "Writing crontab entry to start the writer script on reboot..."
(crontab -l 2>/dev/null; echo "@reboot sudo $MAIN_SCRIPT_PATH") | crontab -

# Update package lists and install necessary dependencies
echo "Updating package lists..."
sudo apt-get update -y

echo "Installing required packages..."
sudo apt-get install -y util-linux parted dosfstools p7zip-full git

# Clone the latest repository to ensure we're using the most up-to-date scripts
echo "Cloning the latest version of the repository..."
cd /tmp
sudo rm -rf NYX-RE
git clone $GIT_REPO
cd NYX-RE

# Copy the usb_writer.sh script to the appropriate location
echo "Copying the main USB writer script..."
cp usb_writer.sh "$MAIN_SCRIPT_PATH"

# Make the script executable
sudo chmod +x "$MAIN_SCRIPT_PATH"

# Ensure the /opt/iso directory exists
if [ ! -d "/opt/iso" ]; then
    echo "Creating /opt/iso directory..."
    sudo mkdir -p /opt/iso
fi

# Download and extract the ISO file if versioning indicates an update
if [ -f "$VERSION_FILE" ] && [ -f "$URL_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    DOWNLOAD_URL=$(cat "$URL_FILE")

    # Clean the download URL by removing everything after the '?' and adding "download=1"
    CLEANED_URL=$(echo "$DOWNLOAD_URL" | sed 's/\?.*/?download=1/')

    echo "Downloading ISO from cleaned URL: $CLEANED_URL"

    # Download the ISO to a temporary file
    wget -O "$TEMP_ISO" "$CLEANED_URL"

    if [ $? -eq 0 ]; then
        echo "Download successful, moving to $ISO_PATH"
        mv "$TEMP_ISO" "$ISO_PATH"
    else
        echo "Error downloading the ISO."
        exit 1
    fi
else
    echo "Error: Version or URL file missing."
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

echo "Setup complete! You can now run the script using: sudo $MAIN_SCRIPT_PATH"
