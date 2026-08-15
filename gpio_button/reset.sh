#!/usr/bin/env bash
# reset.sh — revert the GPIO button patches from an h618-android12.0 tree.
#
# Usage:
#   $ cd path/to/h618-android12.0
#   $ ~/H618-Android12-patches/gpio_button/reset.sh
#

set -euo pipefail

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

echo "==> Reverting GPIO button changes"
git -C "${REPO_ROOT}" checkout -- \
    longan/device/config/chips/h618/configs/p2/linux-5.4/board-k2b.dts \
    longan/device/config/chips/h618/configs/p2/linux-5.4/board-k2c.dts \
    longan/kernel/linux-5.4/drivers/pinctrl/sunxi/pinctrl-sun50iw9.c

echo "==> Done. GPIO button changes reverted."
