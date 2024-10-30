#!/bin/bash

# Variables
ISO_DIR="/opt/iso/winpe"  # Directory containing extracted Windows PE files
USB_LABEL="WinPE"
USB_WRITTEN_DEVICES=()  # Array to track devices that have been written to
SYSTEM_DRIVES=($(lsblk -o NAME,MODEL | grep -E "/|nvme|sda|vda" | awk '{print $1}'))  # Detect system drives (excluding typical USB names)
VERSION_FILE="/opt/iso/version.txt"
URL_FILE="/opt/iso/download_url.txt"
TEMP_ISO="/opt/iso/nyx_temp.iso"

# Function to prepare the USB drive
prepare_usb_drive() {
    USB_DEVICE=$1

    echo "Preparing USB drive: /dev/$USB_DEVICE"

    # Create a new partition table
    sudo parted /dev/$USB_DEVICE --script mklabel msdos

    # Create a single primary partition taking up the whole drive
    sudo parted -a optimal /dev/$USB_DEVICE mkpart primary fat32 0% 100%

    # Set the boot flag on the partition
    sudo parted /dev/$USB_DEVICE set 1 boot on

    # Format the new partition to FAT32
    sudo mkfs.vfat -F 32 -n "$USB_LABEL" /dev/${USB_DEVICE}1
}

# Function to write Windows PE to USB
write_winpe_to_usb() {
    USB_DEVICE=$1

    echo "Writing Windows PE to the USB drive..."

    # Create mount point if it doesn't exist
    if [ ! -d /mnt ]; then
        sudo mkdir /mnt
    fi

    # Mount the USB drive
    sudo mount /dev/${USB_DEVICE}1 /mnt
    
    # Copy the Windows PE files to the USB drive
    cp -r "$ISO_DIR"/* /mnt

    sudo umount /mnt
    echo "Windows PE has been written to the USB drive."
    USB_WRITTEN_DEVICES+=("$USB_DEVICE")  # Add the device to the written list
}

# Function to check if a device is a system drive
is_system_drive() {
    USB_DEVICE=$1

    # Check if the drive is in the list of system drives
    if [[ " ${SYSTEM_DRIVES[@]} " =~ " ${USB_DEVICE} " ]]; then
        return 0  # It's a system drive
    else
        return 1  # It's not a system drive
    fi
}

# Function to check and update the ISO if needed
check_and_update_iso() {
    if [ -f "$VERSION_FILE" ] && [ -f "$URL_FILE" ]; then
        CURRENT_VERSION=$(cat "$VERSION_FILE")
        DOWNLOAD_URL=$(cat "$URL_FILE")

        # Clean the download URL by removing everything after the '?' and adding "download=1"
        CLEANED_URL=$(echo "$DOWNLOAD_URL" | sed 's/\?.*/?download=1/')

        echo "Checking for new ISO version... (current version: $CURRENT_VERSION)"

        # Download the ISO to a temporary file
        wget -O "$TEMP_ISO" "$CLEANED_URL"

        if [ $? -eq 0 ]; then
            echo "Download successful, moving to $ISO_DIR/winpe.iso"
            mv "$TEMP_ISO" "/opt/iso/winpe.iso"
            echo "ISO updated successfully."
            # Optionally extract the ISO here if needed
        else
            echo "Error downloading the ISO."
            exit 1
        fi
    else
        echo "Error: Version or URL file missing."
        exit 1
    fi
}

# Main loop to detect and process USB insertion
while true; do
    # Check and update ISO
    check_and_update_iso

    # Detect all connected USB block devices (excluding partitions)
    USB_DRIVES=($(lsblk -o NAME,TYPE,TRAN | grep "disk" | grep "usb" | awk '{print $1}'))

    for USB_DRIVE in "${USB_DRIVES[@]}"; do
        # Skip system drives early
        if is_system_drive $USB_DRIVE; then
            echo "Skipping system drive /dev/$USB_DRIVE."
            continue
        fi

        # Check if the USB has already been written to
        if [[ " ${USB_WRITTEN_DEVICES[@]} " =~ " ${USB_DRIVE} " ]]; then
            echo "USB drive /dev/$USB_DRIVE has already been written to. Skipping..."
        else
            echo "USB drive detected: /dev/$USB_DRIVE"

            # Unmount the USB drive before writing
            sudo umount /dev/${USB_DRIVE}* 2>/dev/null

            # Prepare the USB drive
            prepare_usb_drive $USB_DRIVE
            
            # Write Windows PE to the USB drive
            write_winpe_to_usb $USB_DRIVE
        fi
    done

    # Clean up the list of written devices if they are unplugged
    for written_device in "${USB_WRITTEN_DEVICES[@]}"; do
        if ! lsblk -o NAME | grep -q "$written_device"; then
            echo "USB drive /dev/$written_device has been unplugged. Removing from written list."
            USB_WRITTEN_DEVICES=("${USB_WRITTEN_DEVICES[@]/$written_device}")  # Remove unplugged device
        fi
    done

    # Wait for a bit before checking again
    sleep 5
done
