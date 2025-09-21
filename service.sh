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
    # Use first argument as ZRAM device or default to zram0
    ZRAM_DEV="/dev/block/${1:-zram0}"
    ZRAM_SYS="/sys/block/${1:-zram0}"
    
    # Validate ZRAM device exists
    [ ! -b "$ZRAM_DEV" ] && return 1

    # Detect RAM in MB
    RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    [ -z "$RAM_MB" ] || [ "$RAM_MB" -le 0 ] && return 1

    # ZRAM size = 50% of RAM by default (override with $2 if given)
    ZRAM_MB=$((RAM_MB / 2))
    [ -n "$2" ] && [ "$2" -gt 0 ] && ZRAM_MB="$2"
    [ "$ZRAM_MB" -le 0 ] && return 1

    # Turn off existing ZRAM swap and reset
    swapoff "$ZRAM_DEV" 2>/dev/null
    echo 1 > "$ZRAM_SYS/reset" 2>/dev/null

    # Set compression algorithm (lz4 preferred, fallback to lzo)
    grep "lz4" "$ZRAM_SYS/comp_algorithm" 2>/dev/null && echo "lz4" > "$ZRAM_SYS/comp_algorithm" 2>/dev/null || 
    grep "lzo" "$ZRAM_SYS/comp_algorithm" 2>/dev/null && echo "lzo" > "$ZRAM_SYS/comp_algorithm" 2>/dev/null

    # Apply new size
    echo "${ZRAM_MB}M" > "$ZRAM_SYS/disksize" 2>/dev/null || return 1

    # Reinitialize swap
    mkswap "$ZRAM_DEV" 2>/dev/null && swapon "$ZRAM_DEV" -p 32767 2>/dev/null

    # VM tweaks
    sysctl -w vm.swappiness=40 2>/dev/null
    sysctl -w vm.page-cluster=0 2>/dev/null
}

xset_iostat() {
    [ $# -lt 2 ] && return 1
    
    enable="$1"
    shift
    
    [ "$(id -u)" -ne 0 ] && return 1
    
    for device in "$@"; do
        iostat_path="/sys/block/$device/queue/iostats"
        [ -e "$iostat_path" ] && echo "$enable" > "$iostat_path" 2>/dev/null
    done
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

# Disable IOStats
xset_iostat 0 sda sdb sdc sde sdd sdf mmcblk1