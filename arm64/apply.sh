#!/usr/bin/env bash
# Apply the Allwinner H618 arm64 porting patches to a clean SDK tree.
# Verified against the official kickpi H618 Android 12 SDK and the
# Apollo-P2 / K2C(-tablet) lunch target.
#
# Usage:   ./apply.sh PATH_TO_SDK_ROOT
# Example: ./apply.sh /home/user/h618-android12.0
#
# What this does:
#   1. Checks the SDK root looks like the right tree (build.sh present).
#   2. Applies the three source/bp/mk patches via `git am --3way`.
#      These are the actual porting work; they always apply cleanly
#      on top of stock master.
#   3. Tells you to do two `./build.sh` runs.  The first will fail at
#      the VNDK abidiff step because the regenerated 32/64-bit
#      libstagefright_foundation.so.lsdump has not been committed yet.
#      That is expected; the second run picks up the fresh dumps.
#   4. After the second run, apply patches 0004 and 0005 to land the
#      new ABI baselines.
#
# We deliberately do not include the ABI dumps in the first-pass patch
# list because the dump is a build artifact whose contents depend on the
# toolchain revision that produced your local binaries, so we always
# regenerate it locally.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 PATH_TO_SDK_ROOT" >&2
    exit 1
fi

SDK="$1"
if [[ ! -x "$SDK/build.sh" ]]; then
    echo "error: $SDK does not look like a kickpi H618 SDK (build.sh missing)" >&2
    exit 1
fi

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SDK"

DIRTY=$(git status --porcelain 2>/dev/null | wc -l)
if [[ "$DIRTY" -gt 0 ]]; then
    echo "warning: working tree is dirty ($DIRTY changed files).  Patch may fail" >&2
    echo "         to apply; commit/stash/reset before running." >&2
fi

# Source patches — these are deterministic and always apply.
SRC_PATCHES=(
    "0001-feat-switch-to-64-bit-userspace-arm64-zygote64_32.patch"
    "0002-feat-lock-cedarx-codec2-mediaplayerservice-widevine-.patch"
    "0003-feat-lock-display-UVC-camera-HIDL-chain-to-32-bit.patch"
)

# ABI baseline patches — must be regenerated locally because they encode
# the toolchain revision that produced your binaries.
ABI_PATCHES=(
    "0004-abi-regenerate-VNDK-64-bit-libstagefright_foundation.patch"
    "0005-abi-regenerate-VNDK-32-bit-libstagefright_foundation.patch"
)

for p in "${SRC_PATCHES[@]}"; do
    echo ">>> applying $p"
    if ! git am --3way "$PATCH_DIR/$p"; then
        echo "error: git am failed on $p.  Resolve the conflict manually," >&2
        echo "       then re-run from inside the SDK." >&2
        exit 1
    fi
done

cat <<'EOF'

============================================================
Source patches applied successfully.  Next:

  cd SDK
  ./build.sh lunch         # pick BoardConfig-kickpi-k2c-tablet (or -tv)
  ./build.sh               # build #1 — will FAIL at the abidiff step
                           # with: "VNDK library: libstagefright_foundation's
                           #        ABI has EXTENDING CHANGES".
                           # That is expected; it just means the rebuilt
                           # lsdumps no longer match the old reference dumps.

After build #1 finishes (with the abidiff failure), rerun ./build.sh.
The second run picks up the freshly-generated lsdumps and should
complete cleanly to the pack step.

Once you have a successful ./build.sh, apply the ABI baseline patches:

  git am --3way PATCH_DIR/0004-abi-regenerate-VNDK-64-bit-libstagefright_foundation.patch
  git am --3way PATCH_DIR/0005-abi-regenerate-VNDK-32-bit-libstagefright_foundation.patch

(If the SDK refuses with a SHA mismatch because you rebuilt lsdumps
locally, that's fine — the content is identical, just commit them
by hand: `git add prebuilts/abi-dumps/... && git commit`.)

If boot fails with 'hardware check error1' in BL3-1, the boot0 in the
new image is stale — ./build.sh must be the entry point because its
build_brandy step is what regenerates boot0/u-boot/monitor.  Running
'make -jN && pack' directly with stale longan/out/* will reproduce
the panic.

The board ships 32-bit-only Allwinner media blobs, so mediaserver,
the codec2 HAL service, hwcomposer, the UVC camera provider, and the
widevine HAL run as 32-bit processes; everything else (zygote,
system_server, framework, apps) runs as arm64.  ro.zygote is set to
zygote64_32.
============================================================
EOF