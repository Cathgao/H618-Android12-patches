#!/usr/bin/env bash
# apply.sh — one-shot install of all eGTouchD / eGalaxCalibrator /
# serial-port / GPIO / SELinux changes on top of a freshly `git reset --hard`'d
# h618-android12.0 working tree.
#
# Usage:
#   $ cd path/to/h618-android12.0   # Android source root
#   $ ~/h618-patches/apply.sh        # apply
#   $ ./build.sh android            # build
#   $ longan/out/update-h618-kickpi-k2c-android12-tablet-*.img  # flash
#
# What this script does:
#   1. Verifies the working tree is at a clean HEAD (we want diff/ to apply
#      cleanly). Existing un-flushed changes are NOT touched; see reset.sh to
#      drop them first.
#   2. Applies the 5 git-format diffs in diff/ which carry every modified
#      tracked file.
#   3. Copies the untracked source-tree additions (Android.* files for
#      eGTouchD, egtouchd.te, eGalaxCalibrator Android.mk) from source/.
#   4. Copies the binary payloads (eGTouchD, libstdc++.eGTouchD.so,
#      liblog.eGTouchD.so, eGalaxCalibrator.apk) from binaries/ into the
#      device tree.
#   5. Runs non-trivial preparations that can't be expressed as a patch:
#      nothing today, but the step is reserved for future hooks.
#
# Failure modes:
#   - Any git apply failure aborts before the rest of the diffs run.
#   - Patches are assumed to apply to the current HEAD. Run reset.sh first
#     if HEAD has moved on.

set -euo pipefail

# --- help / version flags (do these BEFORE the dirty-tree check so
#     --help never accidentally touches the source tree) ---
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,30p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

# --- paths ---
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the h618-android12.0 source root.  The merged patch layout puts
# this script at ~/h618-patches/egtouch/apply.sh, with the SDK as a
# sibling of the parent: ~/h618-android12.0.  Walk up from HERE looking
# for a directory named h618-android12.0 that contains .git (the
# ancestor case, when this script lives inside the source tree); fall
# back to a sibling-of-ancestor lookup (the typical ~/h618-patches next
# to ~/h618-android12.0 case).  Stop at /.
REPO_ROOT=""
CUR="${HERE}"
while [[ "${CUR}" != "/" ]]; do
    # First check whether CUR itself is the SDK source root.
    if [[ "$(basename "${CUR}")" == h618-android12.0 && -d "${CUR}/.git" ]]; then
        REPO_ROOT="${CUR}"
        break
    fi
    # Then check whether a sibling named h618-android12.0 of CUR exists.
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
SOURCE_DIR="${HERE}/source"
BIN_DIR="${HERE}/binaries"

# --- preconditions ---
if [[ ! -d "${REPO_ROOT}/.git" ]]; then
    echo "ERROR: ${REPO_ROOT} is not a git repository" >&2
    exit 2
fi

# Refuse to run if our own target files have pending local changes that
# would conflict.  We check ONLY the paths touched by our own diffs —
# other dirty files in the working tree are not our concern, because
# this patch's paths are disjoint from arm64/ and audio_policy/.  Running
# this after `apply.sh` (which applies arm64 + leaves the tree dirty
# relative to upstream HEAD) is the expected workflow.
#
# We extract the pathspecs from our own diffs so adding a new *.diff
# automatically extends the guard set — no manual list to maintain.
#
# Pass --force to skip this check.
if [[ "${1:-}" != "--force" ]]; then
    EGT_PSPEC=()
    while IFS= read -r p; do
        [[ -n "${p}" ]] && EGT_PSPEC+=("${p}")
    done < <(grep -h "^diff --git" "${DIFF_DIR}"/*.diff \
             | awk '{print $3}' | sed 's|^a/||' | sort -u)
    if [[ ${#EGT_PSPEC[@]} -gt 0 ]]; then
        if ! git -C "${REPO_ROOT}" diff --quiet --no-ext-diff HEAD -- "${EGT_PSPEC[@]}"; then
            echo "ERROR: eGTouch target files have unstaged changes. Run reset.sh first or" >&2
            echo "       pass --force to attempt apply anyway." >&2
            exit 2
        fi
        if ! git -C "${REPO_ROOT}" diff --quiet --no-ext-diff --cached HEAD -- "${EGT_PSPEC[@]}"; then
            echo "ERROR: eGTouch target files have staged changes. Run reset.sh first." >&2
            exit 2
        fi
    fi
fi

# --- step 1: git apply diffs ---
# Apply in numeric order so dependencies (e.g. sepolicy type declarations vs
# neverallow references) are applied in a consistent order.
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

# --- step 2: copy source-tree additions ---
echo "==> Copying source-tree additions"
case "${SOURCE_DIR}/device/softwinner/apollo/common/eGTouch/Android.mk" in
    */*) cp -r "${SOURCE_DIR}/device/softwinner/apollo/common/eGTouch" \
            "${REPO_ROOT}/device/softwinner/apollo/common/" ;;
    *) echo "WARN: eGTouchD source tree missing under source/ — skipping" ;;
esac

if [[ -f "${SOURCE_DIR}/device/softwinner/common/sepolicy/vendor/egtouchd.te" ]]; then
    cp "${SOURCE_DIR}/device/softwinner/common/sepolicy/vendor/egtouchd.te" \
        "${REPO_ROOT}/device/softwinner/common/sepolicy/vendor/"
fi

if [[ -d "${SOURCE_DIR}/vendor/aw/homlet/prebuild/eGalaxCalibrator" ]]; then
    cp -r "${SOURCE_DIR}/vendor/aw/homlet/prebuild/eGalaxCalibrator" \
        "${REPO_ROOT}/vendor/aw/homlet/prebuild/"
fi

# --- step 3: copy binary payloads ---
echo "==> Copying binary payloads"
if [[ -f "${BIN_DIR}/eGTouchD" ]]; then
    cp -f "${BIN_DIR}/eGTouchD" \
        "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/eGTouchD"
fi
if [[ -f "${BIN_DIR}/libstdc++.eGTouchD.so" ]]; then
    cp -f "${BIN_DIR}/libstdc++.eGTouchD.so" \
        "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/libstdc++.eGTouchD.so"
fi
if [[ -f "${BIN_DIR}/liblog.eGTouchD.so" ]]; then
    cp -f "${BIN_DIR}/liblog.eGTouchD.so" \
        "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/liblog.eGTouchD.so"
fi
if [[ -f "${BIN_DIR}/eGTouchA.ini" ]]; then
    cp -f "${BIN_DIR}/eGTouchA.ini" \
        "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/eGTouchA.ini"
fi
if [[ -f "${BIN_DIR}/eGalaxTouch_VirtualDevice.idc" ]]; then
    cp -f "${BIN_DIR}/eGalaxTouch_VirtualDevice.idc" \
        "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/eGalaxTouch_VirtualDevice.idc"
fi
if [[ -f "${BIN_DIR}/eGalaxCalibrator.apk" ]]; then
    cp -f "${BIN_DIR}/eGalaxCalibrator.apk" \
        "${REPO_ROOT}/vendor/aw/homlet/prebuild/eGalaxCalibrator/eGalaxCalibrator.apk"
fi

# --- step 4: post-apply sanity ---
echo "==> Sanity checks"
[[ -f "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/eGTouchD" ]] || \
    { echo "ERROR: eGTouchD binary missing after apply" >&2; exit 4; }
[[ -f "${REPO_ROOT}/device/softwinner/apollo/common/eGTouch/libstdc++.eGTouchD.so" ]] || \
    { echo "ERROR: libstdc++.eGTouchD.so missing after apply" >&2; exit 4; }
[[ -f "${REPO_ROOT}/device/softwinner/common/sepolicy/vendor/egtouchd.te" ]] || \
    { echo "ERROR: egtouchd.te missing after apply" >&2; exit 4; }
[[ -f "${REPO_ROOT}/vendor/aw/homlet/prebuild/eGalaxCalibrator/eGalaxCalibrator.apk" ]] || \
    { echo "ERROR: eGalaxCalibrator.apk missing after apply" >&2; exit 4; }

echo "==> Done. Next:  cd ${REPO_ROOT} && ./build.sh android"
