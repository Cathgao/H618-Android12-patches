#!/usr/bin/env bash
# Top-level wrapper for ~/h618-patches/.  Applies the arm64 64-bit
# porting patches, the eGTouch resistive-touch patches, and the
# audio_policy USB-HAL override against an h618-android12.0 source
# tree, individually or all together, in any order.
#
# Usage:
#   ~/H618-Android12-patches/apply.sh [--only=arm64|egtouch|audio_policy|livetranslate|gpio_button] [SDK_ROOT]
#
# - With no arguments, applies ALL FIVE patch sets in this order:
#     1. arm64        — git am the 5 porting patches (commit-style)
#     2. egtouch      — git apply the 5 .diff files + copy source/binaries
#     3. audio_policy — git apply the 1 .diff file (no source/binaries)
#     4. livetranslate— copy source/binaries + add to homlet.mk
#     5. gpio_button  — git apply GPIO button patches (Pin 14 & 16)
#   The order is irrelevant (the sets touch disjoint paths or append safely).
#
# - With --only=arm64, only the arm64 patch set is applied.
# - With --only=egtouch, only the eGTouch patch set is applied.
# - With --only=audio_policy, only the audio_policy patch set is applied.
# - With --only=livetranslate, only the livetranslate patch set is applied.
# - With --only=gpio_button, only the gpio_button patch set is applied.
#
# - SDK_ROOT defaults to ~/h618-android12.0 (or whatever the path-discovery
#   logic resolves to).  Pass an explicit path to override.
#
# See ./arm64/README.md, ./egtouch/README.md, ./audio_policy/README.md,
# ./livetranslate/README.md and ./gpio_button/README.md for details on each set.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ONLY=""
SDK=""
for arg in "$@"; do
    case "${arg}" in
        --only=*)
            ONLY="${arg#--only=}"
            case "${ONLY}" in
                arm64|egtouch|audio_policy|livetranslate|gpio_button) ;;
                *)
                    echo "ERROR: --only must be 'arm64', 'egtouch', 'audio_policy', 'livetranslate', or 'gpio_button' (got '${ONLY}')" >&2
                    exit 2
                    ;;
            esac
            ;;
        --help|-h)
            sed -n '2,25p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            SDK="${arg}"
            ;;
    esac
done

run_arm64() {
    echo
    echo "================================================================"
    echo "arm64 64-bit porting patches"
    echo "================================================================"
    # Do NOT use exec here — exec would replace the current shell
    # process so subsequent steps would never run when all sets are applied.
    if [[ -n "${SDK}" ]]; then
        "${HERE}/arm64/apply.sh" "${SDK}"
    else
        "${HERE}/arm64/apply.sh" ~/h618-android12.0
    fi
}

run_egtouch() {
    echo
    echo "================================================================"
    echo "eGTouch resistive-touch patches"
    echo "================================================================"
    if [[ -n "${SDK}" ]]; then
        REPO_ROOT="${SDK}" "${HERE}/egtouch/apply.sh"
    else
        "${HERE}/egtouch/apply.sh"
    fi
}

run_audio_policy() {
    echo
    echo "================================================================"
    echo "audio_policy USB-HAL override patches"
    echo "================================================================"
    if [[ -n "${SDK}" ]]; then
        REPO_ROOT="${SDK}" "${HERE}/audio_policy/apply.sh"
    else
        "${HERE}/audio_policy/apply.sh"
    fi
}

run_livetranslate() {
    echo
    echo "================================================================"
    echo "LiveTranslate privileged system app preinstall patch"
    echo "================================================================"
    if [[ -n "${SDK}" ]]; then
        REPO_ROOT="${SDK}" "${HERE}/livetranslate/apply.sh"
    else
        "${HERE}/livetranslate/apply.sh"
    fi
}

run_gpio_button() {
    echo
    echo "================================================================"
    echo "GPIO Button (Pin 14 & 16) patch"
    echo "================================================================"
    if [[ -n "${SDK}" ]]; then
        REPO_ROOT="${SDK}" "${HERE}/gpio_button/apply.sh"
    else
        "${HERE}/gpio_button/apply.sh"
    fi
}

if [[ -n "${ONLY}" ]]; then
    case "${ONLY}" in
        arm64) run_arm64 ;;
        egtouch) run_egtouch ;;
        audio_policy) run_audio_policy ;;
        livetranslate) run_livetranslate ;;
        gpio_button) run_gpio_button ;;
    esac
    exit 0
fi

# Default: apply all five.
run_arm64
run_egtouch
run_audio_policy
run_livetranslate
run_gpio_button

cat <<'EOF'

============================================================
All patch sets applied.  Next:

  cd ~/h618-android12.0
  ./build.sh lunch              # pick BoardConfig-kickpi-k2c-tablet
  ./build.sh                    # build #1 — abidiff will fail; expected
  ~/h618-patches/arm64/regenerate-abi.sh ~/h618-android12.0
  ./build.sh                    # build #2 — should reach "pack image ok!"

After the eGTouch patches have been applied, a regular debug APK can
open /dev/ttyS*, /dev/ttyAS*, /dev/gpiochip*, and the calibration
tool is reachable from the launcher.

After the audio_policy patch has been applied, a USB audio device
plugged into the on-board USB Type-A port will be enumerated by
AudioFlinger (verify with `adb shell dumpsys media.audio_policy`).

After the LiveTranslate patch has been applied, LiveTranslate is
preinstalled under /system/priv-app/LiveTranslate/ with platform signature.
============================================================
EOF
