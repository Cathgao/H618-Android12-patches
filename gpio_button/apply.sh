#!/usr/bin/env bash
# apply.sh — add GPIO button support on 40-pin header pins 14 (GND) & 16 (PI11)
# with 100ms debounce and KEY_F1 event mapped into Android input system.
#
# Usage:
#   $ cd path/to/h618-android12.0
#   $ ~/H618-Android12-patches/gpio_button/apply.sh
#

set -euo pipefail

for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,10p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
    esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    exit 2
fi

DIFF_DIR="${HERE}/diff"

echo "==> Applying GPIO Button patches"
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

echo "==> Done. GPIO button patches applied successfully."
