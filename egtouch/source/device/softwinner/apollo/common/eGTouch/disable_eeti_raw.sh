#!/vendor/bin/sh

# disable_eeti_raw.sh — runs at boot_completed to prevent the kernel's
# built-in hid-multitouch driver from feeding duplicate touch events to
# Android InputManager. The eGTouchD daemon reads the same touch data
# over /dev/hidraw<N> and synthesizes virtual events at /dev/input/event<N>,
# but when BOTH paths are active, InputDispatcher produces
#   "Dropping move event because a pointer for a different device is
#    already active in display 0"
#   "Permission denied, dropping the motion (isPointer=true)"
# for every gesture after the first touch — making button taps unreliable.
#
# Background:
#  The EETI USB panel (VID=0x0eef PID=0x0001) is enumerated by the kernel
#  as a HID multitouch device. The kernel's hid-multitouch driver binds
#  to it and creates evdev nodes (/dev/input/event<N>) which the
#  Android InputManager consumes. eGTouchD simultaneously opens
#  /dev/hidraw<N> for the same hardware and creates its own evdev nodes
#  via /dev/uinput. Both sets of nodes feed events into InputManager.
#
# Approaches that DON'T work (documented so future contributors don't
# waste time on them):
#  * `chmod 000 /dev/input/event<N>` — InputManager already holds the fd
#    from boot enumeration, so the device stays "Enabled" in dumpsys.
#  * `echo 0 > authorized` — drops the entire USB device including
#    hidraw<N>; eGTouchD loses its source fd and re-detection requires
#    physical re-plug of the panel.
#  * `echo <hwaddr> > /sys/bus/hid/drivers/hid-multitouch/unbind` —
#    HID core re-probes and re-binds within ~1 s, faster than any
#    shell script can finish. Single unbind is useless.
#  * `chmod 666` then `unbind` — same race; the rebind wins.
#
# What DOES work: chmod 000 the physical evdev nodes the moment the
# kernel creates them. After re-plug (or boot), the kernel re-creates
# /dev/input/eventN as 0660 root:input (per /system/etc/ueventd.rc), so
# this script must chmod 000 them again, and keep doing so on every
# fresh enumeration. We don't kill the device — we just make its evdev
# nodes inaccessible to Android InputManager. eGTouchD continues to read
# /dev/hidraw<N> normally and feeds events through /dev/uinput.
#
# Triggered from init.sun50iw9p1.rc via exec_background in
# on property:sys.boot_completed=1.

LOCK_FILE=/data/eGalax/disable_eeti_raw.lock

# Mark our presence in /data/eGalax (directory created in post-fs-data).
mkdir -p /data/eGalax 2>/dev/null
echo "$$ $(date +%s)" > "$LOCK_FILE" 2>/dev/null

log_eeti() {
    log -t eETI "$1"
}

log_eeti "disable_eeti_raw.sh started (pid=$$)"

# One-shot chmod 000 of the EETI evdev nodes. We look for the
# combination of VID/PID via /sys/class/input instead of /sys/bus/usb so
# that this works even after the device has been re-enumerated under
# a new bus number.
#
# This script runs ONCE at boot_completed, just before restart_services.sh
# tears system_server down and brings it back up. The order matters:
#   1. eGTouchD (started earlier by init.rc) has opened its hidraw fd and
#      created virtual event nodes via uinput.
#   2. This script chmod 000s the physical event nodes (the duplicate
#      sources).
#   3. restart_services.sh restarts system_server, which re-initializes
#      InputManager. InputManager re-reads /sys/class/input, sees the
#      0000 permissions, and only opens the virtual nodes (event6, event7
#      — vendor=0eef product=0020/0030). The duplicate-event storm is
#      gone.
#
# If you ever need to re-run this on a running device (e.g. after a
# touch-panel re-plug while adb-debugging), invoke it manually:
#   adb shell su 0 /vendor/bin/disable_eeti_raw.sh
for dev in /sys/class/input/event*; do
    [ -e "$dev" ] || continue
    # Touchscreen nodes for the EETI panel carry VID=0eef PID=0001.
    vendor=$(cat "$dev/device/id/vendor" 2>/dev/null)
    product=$(cat "$dev/device/id/product" 2>/dev/null)
    if [ "$vendor" = "0eef" ] && [ "$product" = "0001" ]; then
        node="/dev/input/$(basename "$dev")"
        # Skip nodes that eGTouchD already manages (vendor=0eef but
        # product=0x0020 / 0x0030 — these are the VirtualDevice /
        # VirtualPen created via uinput).
        chmod 000 "$node" 2>/dev/null
        log_eeti "chmod 000 $node (vendor=$vendor product=$product)"
    fi
done
log_eeti "disable_eeti_raw.sh done"