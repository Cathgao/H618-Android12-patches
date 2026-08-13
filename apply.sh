#!/usr/bin/env bash
# Top-level wrapper for ~/h618-patches/.  Applies the arm64 64-bit
# porting patches, the eGTouch resistive-touch patches, and the
# audio_policy USB-HAL override against an h618-android12.0 source
# tree, individually or all together, in any order.
#
# Usage:
#   ~/h618-patches/apply.sh [--only=arm64|egtouch|audio_policy] [SDK_ROOT]
#
# - With no arguments, applies ALL THREE patch sets in this order:
#     1. arm64        — git am the 5 porting patches (commit-style)
#     2. egtouch      — git apply the 5 .diff files + copy source/binaries
#     3. audio_policy — git apply the 1 .diff file (no source/binaries)
#   The order is irrelevant (the three sets touch disjoint paths);
#   arm64 goes first only because its README asks you to run
#   `./build.sh lunch` and a pair of builds afterwards, and it's
#   useful to surface that step's output before the eGTouch SELinux
#   work shows up.  audio_policy runs last so its single-file diff
#   is the most recent working-tree change.
#
# - With --only=arm64, only the arm64 patch set is applied.
# - With --only=egtouch, only the eGTouch patch set is applied.
# - With --only=audio_policy, only the audio_policy patch set is applied.
#
# - SDK_ROOT defaults to ~/h618-android12.0 (or whatever the eGTouch
#   path-discovery logic resolves to).  Pass an explicit path to override.
#
# See ./arm64/README.md, ./egtouch/README.md and ./audio_policy/README.md
# for details on each set.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ONLY=""
SDK=""
for arg in "$@"; do
    case "${arg}" in
        --only=*)
            ONLY="${arg#--only=}"
            case "${ONLY}" in
                arm64|egtouch|audio_policy) ;;
                *)
                    echo "ERROR: --only must be 'arm64', 'egtouch', or 'audio_policy' (got '${ONLY}')" >&2
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
    # process so the eGTouch step below would never run when both
    # sets are applied together.
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
    # egtouch's apply.sh does its own path discovery; an extra SDK arg is
    # unnecessary, but pass one if the user gave it.  No `exec` for the
    # same reason as run_arm64 — we want to continue after this returns.
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
    # audio_policy/apply.sh does its own path discovery; same shape as
    # egtouch.  Order relative to the other two sets is irrelevant (the
    # three touch disjoint paths); we run it last so its single-file
    # diff is the most recent change in `git status` output.
    #
    # IMPORTANT: audio_policy/apply.sh's dirty-tree check is scoped to
    # its own target file only — the whole-tree is almost certainly
    # dirty by this point (arm64 + egtouch both leave changes), but the
    # audio_policy target is disjoint from those changes and the check
    # correctly says "go ahead".
    if [[ -n "${SDK}" ]]; then
        REPO_ROOT="${SDK}" "${HERE}/audio_policy/apply.sh"
    else
        "${HERE}/audio_policy/apply.sh"
    fi
}

if [[ -n "${ONLY}" ]]; then
    case "${ONLY}" in
        arm64) run_arm64 ;;
        egtouch) run_egtouch ;;
        audio_policy) run_audio_policy ;;
    esac
    exit 0
fi

# Default: apply all three.  Order is interchangeable (disjoint paths);
# we pick arm64 → egtouch → audio_policy so the audio_policy change is
# the most recent working-tree diff, and to match the existing default
# flow when audio_policy was the third set to be added.
run_arm64
run_egtouch
run_audio_policy

cat <<'EOF'

============================================================
All three patch sets applied.  Next:

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
============================================================
EOF
