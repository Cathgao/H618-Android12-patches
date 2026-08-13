#!/usr/bin/env bash
# reset.sh — drop the audio policy override and restore the tracked
# file to its kickpi HEAD version.
#
# Use this when you want to start over, or before re-running apply.sh
# on a tree that has been hand-edited.
#
# Usage:
#   $ cd path/to/h618-android12.0
#   $ ~/h618-patches/audio_policy/reset.sh   # revert tracked file
#   $ git reset --hard HEAD                  # optional: also drop any
#                                            # hand edits to the same file

set -euo pipefail

# --- help / version flags (do these BEFORE the dirty-tree check so
#     --help never accidentally nukes a tree) ---
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,12p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the h618-android12.0 source root.  Walk up from HERE looking
# for an ancestor or sibling-of-ancestor named h618-android12.0 with
# a .git directory.  See apply.sh for the matching block.
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

TARGET="device/softwinner/apollo/common/media/audio/audio_policy_configuration.xml"

# --- 1. revert the tracked file we modified ---
echo "==> Reverting tracked file"
git -C "${REPO_ROOT}" checkout -- "${TARGET}"

# --- 2. status ---
echo "==> Done. Working tree status:"
git -C "${REPO_ROOT}" status --short