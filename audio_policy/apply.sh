#!/usr/bin/env bash
# apply.sh — override the kickpi-H618 audio policy configuration with
# the version that adds a full USB Audio HAL module (kickpi HEAD ships
# only the primary module + A2DP + Remote Submix).
#
# Usage:
#   $ cd path/to/h618-android12.0   # Android source root
#   $ ~/h618-patches/audio_policy/apply.sh        # apply
#
# What this script does:
#   1. Verifies the working tree is at a clean HEAD (we want diff/ to apply
#      cleanly). Existing un-flushed changes are NOT touched; see reset.sh
#      to drop them first.
#   2. Applies the git-format diff in diff/01-audio-policy.diff against
#      the tracked file
#         device/softwinner/apollo/common/media/audio/audio_policy_configuration.xml
#      (full-replace of the upstream kickpi version with the USB-aware
#      version, identical content to source/audio_policy_configuration.xml).
#   3. Sanity-checks that the resulting file matches the expected sha256
#      so a botched apply is caught immediately rather than at first boot.
#
# Failure modes:
#   - Any git apply failure aborts before sanity check.
#   - The diff is generated against HEAD; if HEAD has moved on, run
#     reset.sh first then re-run.

set -euo pipefail

# --- help / version flags (do these BEFORE the dirty-tree check so
#     --help never accidentally touches the source tree) ---
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,22p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

# --- paths ---
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the h618-android12.0 source root.  Walk up from HERE looking for
# an ancestor or sibling-of-ancestor named h618-android12.0 with a .git
# directory.  See egtouch/apply.sh for the matching block — same walk-up
# logic, since this script lives at ~/h618-patches/audio_policy/apply.sh
# in the merged layout, with the SDK as a sibling of the parent.
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
    echo "       hint: pass REPO_ROOT=/path/to/h618-android12.0 explicitly" >&2
    exit 2
fi

DIFF_DIR="${HERE}/diff"
TARGET="device/softwinner/apollo/common/media/audio/audio_policy_configuration.xml"

# --- preconditions ---
if [[ ! -d "${REPO_ROOT}/.git" ]]; then
    echo "ERROR: ${REPO_ROOT} is not a git repository" >&2
    exit 2
fi

# Refuse to run if our own target file has pending local changes that
# would conflict.  Unlike egtouch/apply.sh we check ONLY this file —
# other dirty files in the working tree are not our concern, because
# this patch's paths are disjoint from arm64/ and egtouch/.  Running
# this after `apply.sh` (which applies arm64 + egtouch and leaves the
# tree dirty) is the expected workflow.
#
# Pass --force to skip this check.
if [[ "${1:-}" != "--force" ]]; then
    if ! git -C "${REPO_ROOT}" diff --quiet --no-ext-diff HEAD -- "${TARGET}"; then
        echo "ERROR: ${TARGET} has unstaged changes. Run reset.sh first or" >&2
        echo "       pass --force to attempt apply anyway." >&2
        exit 2
    fi
    if ! git -C "${REPO_ROOT}" diff --quiet --no-ext-diff --cached HEAD -- "${TARGET}"; then
        echo "ERROR: ${TARGET} has staged changes. Run reset.sh first." >&2
        exit 2
    fi
fi

# --- step 1: git apply diffs ---
echo "==> Applying diffs"
shopt -s nullglob
for f in "${DIFF_DIR}"/*.diff; do
    echo "    patch $(basename "$f")"
    if ! git -C "${REPO_ROOT}" apply --check "$f"; then
        echo "ERROR: dry-run git apply failed for $f" >&2
        echo "       (run reset.sh then re-run apply.sh)" >&2
        exit 3
    fi
    git -C "${REPO_ROOT}" apply "$f"
done
shopt -u nullglob

# --- step 2: sanity check ---
echo "==> Sanity checks"
if [[ ! -f "${REPO_ROOT}/${TARGET}" ]]; then
    echo "ERROR: ${TARGET} missing after apply" >&2
    exit 4
fi

# Compare the on-disk blob to source/audio_policy_configuration.xml by
# sha256.  Two checks:
#   - SOURCE_SHA matches source/ (catches "source/ was edited but diff
#     wasn't regenerated").
#   - ONDISK_SHA matches SOURCE_SHA (catches "git apply succeeded but
#     produced wrong content" — git won't, but paranoia is cheap).
SOURCE_FILE="${HERE}/source/audio_policy_configuration.xml"
if [[ ! -f "${SOURCE_FILE}" ]]; then
    echo "ERROR: ${SOURCE_FILE} missing" >&2
    exit 4
fi

SOURCE_SHA="$(sha256sum "${SOURCE_FILE}" | awk '{print $1}')"
ONDISK_SHA="$(sha256sum "${REPO_ROOT}/${TARGET}" | awk '{print $1}')"

if [[ "${SOURCE_SHA}" != "${ONDISK_SHA}" ]]; then
    echo "ERROR: post-apply sha256 mismatch" >&2
    echo "       source/: ${SOURCE_SHA}" >&2
    echo "       on-disk: ${ONDISK_SHA}" >&2
    echo "       (diff and source/ are out of sync — regenerate diff)" >&2
    exit 4
fi

echo "==> Done. Target file at ${REPO_ROOT}/${TARGET} now matches source/."