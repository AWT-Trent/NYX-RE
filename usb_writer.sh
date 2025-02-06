#!/bin/bash

# Variables
ISO_DIR="/opt/iso/winpe"  # Directory containing extracted Windows PE files
USB_LABEL="Nyx"
USB_WRITTEN_DEVICES=()  # Array to track devices that have been written to
SYSTEM_DRIVES=($(lsblk -o NAME,MODEL | grep -E "/|nvme|sda|vda" | awk '{print $1}'))  # Detect system drives (excluding typical USB names)
VERSION_FILE="/tmp/NYX-RE/version.txt"
CURRENT_VERSION_FILE="/opt/iso/current_version.txt"


GIT_REPO="https://github.com/AWT-Trent/NYX-RE.git"  # Git repository URL


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
    CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE" | tr -d '[:space:]')
    USB_LABEL_FORMATTED=$(echo "${USB_LABEL}_${CURRENT_VERSION}" | cut -c1-11)
    
    # Format the new partition to FAT32
    sudo mkfs.vfat -F 32 -n "$USB_LABEL_FORMATTED" "/dev/${USB_DEVICE}1"
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
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
        
	# Clone the latest repository to ensure we're using the most up-to-date scripts
        echo "Cloning the latest version of the repository..."

        sudo rm -rf /tmp/NYX-RE
        git clone $GIT_REPO /tmp/NYX-RE
        chmod +x /tmp/NYX-RE/setup.sh
	NEW_VERSION=$(cat "$VERSION_FILE")
	if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then     
            exec /tmp/NYX-RE/setup.sh
        else
            echo "No update needed."

        fi


    else
        echo "Error: Version or URL file missing."
        exit 1
    fi
}

check_and_update_iso

# Main loop to detect and process USB insertion
while true; do
    

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
