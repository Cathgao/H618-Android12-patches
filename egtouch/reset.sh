#!/usr/bin/env bash
# reset.sh — nuke everything apply.sh installed and drop the patches
# back to a clean `git reset --hard` state.
#
# Use this when you want to start over, or before re-running apply.sh on
# a tree that has been hand-edited.
#
# Usage:
#   $ cd path/to/h618-android12.0
#   $ ~/h618-patches/reset.sh          # restore tracked files
#                                       # + remove untracked eGTouchD additions
#   $ git reset --hard HEAD             # optional: also restore tracked files
#                                       # from a manually-edited state

set -euo pipefail

# --- help / version flags (do these BEFORE the dirty-tree check so
#     --help never accidentally nukes a tree) ---
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,14p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the h618-android12.0 source root.  Walk up from HERE looking
# for an ancestor or sibling-of-ancestor named h618-android12.0 with
# a .git directory.  See the matching block in apply.sh for the
# rationale (this script lives at ~/h618-patches/egtouch/reset.sh in
# the merged layout, with the SDK at the sibling-of-parent).
REPO_ROOT=""
CUR="${HERE}"
while [[ "${CUR}" != "/" ]]; do
    if [[ "$(basename "${CUR}")" == h618-android12.0 && -d "${CUR}/.git" ]]; then
        REPO_ROOT="${CUR}"
        break
    fi
    SIB="${CUR}/../h618-android12.0"
    if [[ -d "${SIB}/.git" ]]; then
        REPO_ROOT="$(cd "${SIB}" && pwd)"
        break
    fi
    CUR="$(dirname "${CUR}")"
done

if [[ -z "${REPO_ROOT}" || ! -d "${REPO_ROOT}/.git" ]]; then
    echo "ERROR: could not find an h618-android12.0 source root" >&2
    echo "       (walked up from ${HERE} looking for an ancestor or sibling" >&2
    echo "        named h618-android12.0 with a .git directory)" >&2
    exit 2
fi

# --- 1. revert tracked files we modified ---
echo "==> Reverting tracked files"
git -C "${REPO_ROOT}" checkout -- \
    device/softwinner/.BoardConfig.mk \
    device/softwinner/apollo/apollo_p2.mk \
    device/softwinner/apollo/common/system/init.sun50iw9p1.rc \
    device/softwinner/apollo/common/system/ueventd.sun50iw9p1.rc \
    device/softwinner/common/sepolicy/vendor/file_contexts \
    device/softwinner/common/sepolicy/vendor/untrusted_app.te \
    longan/device/config/chips/h618/configs/p2/sys_config.fex \
    system/sepolicy/prebuilts/api/31.0/private/compat/26.0/26.0.ignore.cil \
    system/sepolicy/prebuilts/api/31.0/private/compat/27.0/27.0.ignore.cil \
    system/sepolicy/prebuilts/api/31.0/private/compat/28.0/28.0.ignore.cil \
    system/sepolicy/prebuilts/api/31.0/private/compat/29.0/29.0.ignore.cil \
    system/sepolicy/prebuilts/api/31.0/private/compat/30.0/30.0.ignore.cil \
    system/sepolicy/prebuilts/api/31.0/public/domain.te \
    system/sepolicy/prebuilts/api/31.0/public/file.te \
    system/sepolicy/private/compat/26.0/26.0.ignore.cil \
    system/sepolicy/private/compat/27.0/27.0.ignore.cil \
    system/sepolicy/private/compat/28.0/28.0.ignore.cil \
    system/sepolicy/private/compat/29.0/29.0.ignore.cil \
    system/sepolicy/private/compat/30.0/30.0.ignore.cil \
    system/sepolicy/public/domain.te \
    system/sepolicy/public/file.te \
    vendor/aw/homlet/homlet.mk

# --- 2. remove untracked additions ---
echo "==> Removing untracked additions"
rm -rf "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch"
rm -f  "${REPO_ROOT}/device/softwinner/common/sepolicy/vendor/egtouchd.te"
rm -rf "${REPO_ROOT}/vendor/aw/homlet/prebuild/eGalaxCalibrator"

# --- 3. status ---
echo "==> Done. Working tree status:"
git -C "${REPO_ROOT}" status --short
