#!/usr/bin/env bash
# Top-level wrapper for ~/h618-patches/ reset.  Reverts whichever
# patch set is requested.
#
# Usage:
#   ~/H618-Android12-patches/reset.sh [--only=arm64|egtouch|audio_policy|livetranslate|gpio_button]
#
# - With no arguments, reverts eGTouch, audio_policy, livetranslate, and gpio_button changes.
#   The arm64 patches are applied as 5 git commits (see arm64/README.md),
#   so reverting them is a git operation — see the message printed at the end.
# - With --only=egtouch, only the eGTouch changes are reverted.
# - With --only=arm64, only the git-revert instructions are printed.
# - With --only=audio_policy, only the audio_policy tracked file is reverted.
# - With --only=livetranslate, only the LiveTranslate preinstall files are reverted.
# - With --only=gpio_button, only the gpio_button changes are reverted.
#
# After running this wrapper, the source tree may still have hand-edits
# left over; run `git -C ~/h618-android12.0 reset --hard HEAD` if you
# want a fully clean tree.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ONLY=""
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
            sed -n '2,20p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument '${arg}'" >&2
            exit 2
            ;;
    esac
done

reset_egtouch() {
    echo
    echo "================================================================"
    echo "Reverting eGTouch resistive-touch patches"
    echo "================================================================"
    "${HERE}/egtouch/reset.sh"
}

reset_audio_policy() {
    echo
    echo "================================================================"
    echo "Reverting audio_policy USB-HAL override"
    echo "================================================================"
    "${HERE}/audio_policy/reset.sh"
}

reset_livetranslate() {
    echo
    echo "================================================================"
    echo "Reverting LiveTranslate preinstall patch"
    echo "================================================================"
    "${HERE}/livetranslate/reset.sh"
}

reset_gpio_button() {
    echo
    echo "================================================================"
    echo "Reverting GPIO Button patches"
    echo "================================================================"
    "${HERE}/gpio_button/reset.sh"
}

reset_arm64_info() {
    cat <<'EOF'

================================================================
Reverting arm64 64-bit porting patches
================================================================
The arm64 patches live as 5 git commits in the SDK's history:

  249cca924a feat: switch to 64-bit userspace (arm64 + zygote64_32)
  f4e7074ac5 feat: lock cedarx/codec2/mediaplayerservice/widevine stack to 32-bit
  65864a32fc feat: lock display + UVC camera HIDL chain to 32-bit
  5f9d5c917b abi: regenerate VNDK arm64 + 32-bit libstagefright_foundation baselines

To revert all five (returns the tree to 32-bit arm, exactly as upstream
kickpi shipped it), do one of:

  # Option A: hard reset, throw away the five commits and any later work.
  cd ~/h618-android12.0
  git reset --hard 900ec204f6     # the commit immediately before 249cca924a

  # Option B: keep the commits in history but null out their effect,
  # generating five revert commits.
  git revert 249cca924a f4e7074ac5 65864a32fc 5f9d5c917b

  # Option C: if you only want to start over on a clean tree without
  # losing the patches, clone a fresh SDK and re-run apply.sh against
  # that one.

(The five-commit list above assumes the current history is unmodified.
Run `git -C ~/h618-android12.0 log --oneline -10` to confirm.)
EOF
}

case "${ONLY}" in
    arm64)
        reset_arm64_info
        exit 0
        ;;
    egtouch)
        reset_egtouch
        ;;
    audio_policy)
        reset_audio_policy
        ;;
    livetranslate)
        reset_livetranslate
        ;;
    gpio_button)
        reset_gpio_button
        ;;
    "")
        # Default: revert eGTouch, audio_policy, livetranslate, and gpio_button; print arm64 instructions.
        reset_egtouch
        reset_audio_policy
        reset_livetranslate
        reset_gpio_button
        reset_arm64_info
        ;;
    *)
        echo "ERROR: invalid --only value '${ONLY}'" >&2
        exit 2
        ;;
esac
