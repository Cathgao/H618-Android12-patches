#!/usr/bin/env bash
# apply.sh — preinstall LiveTranslate APK as a privileged system app
# (/system/priv-app/LiveTranslate/) on top of an h618-android12.0 working tree.
#
# Usage:
#   $ cd path/to/h618-android12.0   # Android source root
#   $ ~/H618-Android12-patches/livetranslate/apply.sh
#   # or top-level: ~/H618-Android12-patches/apply.sh --only=livetranslate
#
# What this script does:
#   1. Locates the SDK root directory (defaults to ~/h618-android12.0 or REPO_ROOT).
#   2. Copies Android.mk from source/ into vendor/aw/homlet/prebuild/LiveTranslate/.
#   3. Copies the binary payload LiveTranslate.apk from binaries/ into the SDK tree.
#   4. Appends LiveTranslate to PRODUCT_PACKAGES in vendor/aw/homlet/homlet.mk (if not already present).
#   5. Runs sanity checks to confirm files exist.
#
# Note:
#   To update the preinstalled APK with a newer version in the future,
#   simply replace binaries/LiveTranslate.apk with your new APK and re-run this script.

set -euo pipefail

# --- help / version flags ---
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,20p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

# --- paths ---
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "${REPO_ROOT}" ]]; then
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
fi

if [[ -z "${REPO_ROOT}" || ! -d "${REPO_ROOT}/.git" ]]; then
    echo "ERROR: could not find an h618-android12.0 source root" >&2
    echo "       hint: pass REPO_ROOT=/path/to/h618-android12.0 explicitly" >&2
    exit 2
fi

SOURCE_DIR="${HERE}/source"
BIN_DIR="${HERE}/binaries"
TARGET_PREBUILD="${REPO_ROOT}/vendor/aw/homlet/prebuild/LiveTranslate"
HOMLET_MK="${REPO_ROOT}/vendor/aw/homlet/homlet.mk"

# --- step 1: copy source-tree additions (Android.mk) ---
echo "==> Installing LiveTranslate prebuild build definition"
mkdir -p "${TARGET_PREBUILD}"
if [[ -d "${SOURCE_DIR}/vendor/aw/homlet/prebuild/LiveTranslate" ]]; then
    cp -r "${SOURCE_DIR}/vendor/aw/homlet/prebuild/LiveTranslate/." "${TARGET_PREBUILD}/"
fi

# --- step 2: copy binary payload (LiveTranslate.apk) ---
echo "==> Copying LiveTranslate.apk payload"
if [[ -f "${BIN_DIR}/LiveTranslate.apk" ]]; then
    cp -f "${BIN_DIR}/LiveTranslate.apk" "${TARGET_PREBUILD}/LiveTranslate.apk"
else
    echo "ERROR: ${BIN_DIR}/LiveTranslate.apk missing" >&2
    exit 4
fi

# --- step 3: register package in homlet.mk ---
if [[ -f "${HOMLET_MK}" ]]; then
    if ! grep -q "LiveTranslate" "${HOMLET_MK}"; then
        echo "==> Adding LiveTranslate to vendor/aw/homlet/homlet.mk"
        cat >> "${HOMLET_MK}" <<'EOF'

PRODUCT_PACKAGES += \
    LiveTranslate
EOF
    else
        echo "==> LiveTranslate already registered in vendor/aw/homlet/homlet.mk"
    fi
else
    echo "ERROR: ${HOMLET_MK} not found" >&2
    exit 4
fi

# --- step 4: sanity checks ---
echo "==> Sanity checks"
[[ -f "${TARGET_PREBUILD}/Android.mk" ]] || \
    { echo "ERROR: ${TARGET_PREBUILD}/Android.mk missing after apply" >&2; exit 4; }
[[ -f "${TARGET_PREBUILD}/LiveTranslate.apk" ]] || \
    { echo "ERROR: ${TARGET_PREBUILD}/LiveTranslate.apk missing after apply" >&2; exit 4; }

echo "==> Done. LiveTranslate preinstall patch applied successfully."
