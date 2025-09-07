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

# Example usage:
set_scheduler kyber