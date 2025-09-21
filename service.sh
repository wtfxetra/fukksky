#!/system/bin/sh

xset_scheduler() {
    if [ $# -lt 2 ]; then
        echo "Usage: xset_scheduler <scheduler> <device1> [device2] [device3] ..."
        return 1
    fi
    
    scheduler="$1"
    shift
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "This function must be run as root"
        return 1
    fi
    
    # iterate through arguments
    for device in "$@"; do
        scheduler_path="/sys/block/$device/queue/scheduler"
        
        if [ -e "$scheduler_path" ]; then
            # Check if the requested scheduler is available
            available_schedulers=$(cat "$scheduler_path")
            case "$available_schedulers" in
                *"$scheduler"*)
                    # Set the scheduler
                    echo "$scheduler" > "$scheduler_path"
                    ;;
            esac
        fi
    done
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

# Wait until system is booted and zram device exists
while [ "$(getprop sys.boot_completed)" != "1" ] || [ ! -e /dev/block/zram0 ]; do
    sleep 1
done

# Extra Time
sleep 20


# Set Swappiness
sysctl -w vm.swappiness=40
sysctl -w vm.page-cluster=0

# Setup ZRam
setup_zram

# Set Sheduler
xset_scheduler kyber sda sdb sdc sdd sde sdf mmcblk1