#!/vendor/bin/sh

# restart_services.sh — invoked once from init.sun50iw9p1.rc at
# boot_completed. The companion disable_eeti_raw.sh has been chmod
# 000ing the EETI physical evdev nodes since on early-boot, but
# InputManager grabbed fds on those nodes long before chmod took
# effect, so it still feeds the framework duplicate touch events
# (Permission denied / Dropping move event).
#
# Sending "stop" + "start" to init via its ctl. property triggers a
# full restart of all init-managed services, including system_server,
# which forces InputManager to drop and re-open its evdev fds. At
# that point the EETI evdev nodes are already 0000, so InputManager
# skips them and keeps only the eGTouchD virtual devices.
#
# This is the only known way to drop already-opened evdev fds without
# modifying the kernel. Verified on H618 / Apollo-p2 / Android 12.
#
# CRITICAL: After `su 0 start` re-initializes all services, the
# boot_completed property fires again, which would re-trigger this
# script in an infinite loop.  To prevent that we write a flag file
# (/data/eGalax/restart_done) and exit immediately if it exists.
#
# After the first run we also sleep 20 s to let system_server and
# InputManager finish re-initializing before the caller (init.rc)
# continues with `start egtouchd`.

FLAG=/data/eGalax/restart_done
if [ -f "$FLAG" ]; then
    log -t eETI "restart_services.sh: already done, skipping"
    exit 0
fi

# Check whether the EETI panel (VID=0eef PID=0001) is actually present.
# If it's not plugged in, there is no dual-source problem and no need
# to restart services — just mark the flag and exit.
found=0
for dev in /sys/class/input/event*; do
    [ -e "$dev" ] || continue
    vendor=$(cat "$dev/device/id/vendor" 2>/dev/null)
    product=$(cat "$dev/device/id/product" 2>/dev/null)
    if [ "$vendor" = "0eef" ] && [ "$product" = "0001" ]; then
        found=1
        break
    fi
done
if [ "$found" = "0" ]; then
    log -t eETI "restart_services.sh: no EETI panel found, skipping"
    # Write the flag anyway so we don't re-check on every boot_completed
    mkdir -p /data/eGalax 2>/dev/null
    echo "done" > "$FLAG" 2>/dev/null
    exit 0
fi

# Write the flag BEFORE calling stop/start, otherwise the boot_completed
# triggered by the restart will re-run this script before we finish.
mkdir -p /data/eGalax 2>/dev/null
echo "done" > "$FLAG" 2>/dev/null

log -t eETI "restart_services.sh: triggering init stop"

# `su 0 stop` and `su 0 start` send the corresponding ctl. messages
# to init, which stops/restarts all services it manages.  Use the
# full path /system/xbin/su because vendor/bin PATH doesn't include
# it under vendor_shell.
SU=/system/xbin/su
$SU 0 stop
sleep 8
log -t eETI "restart_services.sh: triggering init start"
$SU 0 start
# Wait for system_server to restart and InputManager to settle
sleep 20
log -t eETI "restart_services.sh: done"