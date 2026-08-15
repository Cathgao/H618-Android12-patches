#!/usr/bin/env bash
# reset.sh — remove LiveTranslate preinstall files and homlet.mk entry.
#
# Usage:
#   $ cd path/to/h618-android12.0
#   $ ~/H618-Android12-patches/livetranslate/reset.sh
#   # or top-level: ~/H618-Android12-patches/reset.sh --only=livetranslate

set -euo pipefail

# --- help / version flags ---
for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,10p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

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
    exit 2
fi

TARGET_PREBUILD="${REPO_ROOT}/vendor/aw/homlet/prebuild/LiveTranslate"
HOMLET_MK="${REPO_ROOT}/vendor/aw/homlet/homlet.mk"

# --- 1. remove untracked additions ---
echo "==> Removing LiveTranslate prebuild directory"
rm -rf "${TARGET_PREBUILD}"

# --- 2. revert homlet.mk entry ---
if [[ -f "${HOMLET_MK}" ]]; then
    echo "==> Cleaning LiveTranslate from homlet.mk"
    python3 -c "
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
new_content = re.sub(r'\n*PRODUCT_PACKAGES\s*\+=\s*\\\\\s*\n\s*LiveTranslate\s*\n?', '\n', content)
with open(path, 'w') as f:
    f.write(new_content)
" "${HOMLET_MK}"

    # If homlet.mk now matches HEAD exactly, checkout clean
    if git -C "${REPO_ROOT}" diff --quiet vendor/aw/homlet/homlet.mk 2>/dev/null; then
        git -C "${REPO_ROOT}" checkout -- vendor/aw/homlet/homlet.mk 2>/dev/null || true
    fi
fi

echo "==> Done. LiveTranslate preinstall patch reverted."
