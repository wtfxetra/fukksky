#!/system/bin/sh

set_scheduler() {
    local scheduler="$1"

    # Loop through all sd[a-f] devices
    for disk in /sys/block/sd[a-f]; do
        if [ -e "$disk/queue/scheduler" ]; then
            echo "$scheduler" > "$disk/queue/scheduler"
        fi
    done

    # Also set for mmcblk1 if it exists
    if [ -e /sys/block/mmcblk1/queue/scheduler ]; then
        echo "$scheduler" > "/sys/block/mmcblk1/queue/scheduler"
    fi
}

#ZRAM setup function

setup_zram() {
    local ZRAM_DEV=/dev/block/zram0
    local ZRAM_SYS=/sys/block/zram0

    # Detect RAM in MB
    local RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')

    # ZRAM size = 50% of RAM by default (override with $1 if given)
    local ZRAM_MB=$((RAM_MB / 2))
    if [ -n "$1" ]; then
        ZRAM_MB="$1"
    fi

    # Turn off existing ZRAM
    swapoff "$ZRAM_DEV" 2>/dev/null
    echo 1 > "$ZRAM_SYS/reset"

    # Set compression
    echo lz4 > "$ZRAM_SYS/comp_algorithm"

    # Apply new size (with M suffix, safer on Android kernels)
    echo "${ZRAM_MB}M" > "$ZRAM_SYS/disksize"

    # Reinitialize swap
    mkswap "$ZRAM_DEV"
    swapon "$ZRAM_DEV" -p 32767

    # VM tweaks
    sysctl -w vm.swappiness=40
    sysctl -w vm.page-cluster=0

    # Confirm
    echo "ZRAM compression: $(cat $ZRAM_SYS/comp_algorithm)"
    echo "Requested ZRAM size: ${ZRAM_MB} MB"
    echo "Kernel reports: $(cat $ZRAM_SYS/disksize) bytes"
}

sysctl -w vm.swappiness=40
sysctl -w vm.page-cluster=0

setup_zram

set_scheduler kyber