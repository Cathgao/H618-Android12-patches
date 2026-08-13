# h618-patches / audio_policy

Single-file patch that overrides the kickpi-H618 audio policy
configuration with a USB-aware version.

## What this patch does

The kickpi SDK ships a `audio_policy_configuration.xml` (under
`device/softwinner/apollo/common/media/audio/`) that declares three
audio HAL modules:

1. `primary` (Speaker + Built-In Mic + Wired Headset + BT SCO + HDMI Out)
2. A2DP Audio HAL (via `<xi:include>`)
3. Remote Submix Audio HAL (via `<xi:include>`)

This patch replaces that file with a version that also declares a
**USB Audio HAL** module (with `usb_accessory output`, `usb_device
output`, `usb_device input` mix ports and the matching `USB Host Out`
/ `USB Device Out` / `USB Headset Out` / `USB Device In` /
`USB Headset In` device ports and routes).

Without the USB HAL module declaration in audio_policy, Android's
`AudioFlinger` will not enumerate USB audio devices even when the
USB audio HAL is loaded — devices plugged into the on-board USB
Type-A port will be visible to `lsusb` but invisible to
`adb shell dumpsys media.audio_policy` and to any audio app.

## Layout

```
audio_policy/
├── apply.sh           # one-shot installer (idempotent — refuses to run on a dirty tree)
├── reset.sh           # reverts the one tracked file we modified
├── README.md          # this file
├── diff/
│   └── 01-audio-policy.diff     # git-format diff: kickpi HEAD → USB-aware version
└── source/
    └── audio_policy_configuration.xml     # source of truth (sha256-verified by apply.sh)
```

The single tracked file this set modifies |
|---|
| `device/softwinner/apollo/common/media/audio/audio_policy_configuration.xml` |

No new files are added and no other tracked files are touched — this
patch touches a disjoint path from `arm64/` and `egtouch/`, so the
three sets compose cleanly in any order.

## Apply

```bash
cd /path/to/h618-android12.0       # the Android source root
~/h618-patches/audio_policy/apply.sh            # refuses to run on a dirty tree
```

`apply.sh` is idempotent — it short-circuits with `git diff --quiet HEAD`
so it won't overwrite a hand-edited tree. Pass `--force` to skip that check.

If the tree is dirty, run `~/h618-patches/audio_policy/reset.sh` first
to drop the patch, then `git checkout -- <target>` or
`git reset --hard HEAD` to throw away any hand edits, then re-run
`apply.sh`.

## Revert

```bash
cd /path/to/h618-android12.0
~/h618-patches/audio_policy/reset.sh           # reverts the one tracked file
git reset --hard HEAD             # optional: also drop any hand edits
```

`reset.sh` does **not** delete the file in `source/` — that is the
source of truth and stays put.

## Why a separate patch set

The audio policy file lives under `device/softwinner/apollo/common/`,
a path the `arm64/` and `egtouch/` patch sets do not touch. Splitting
this out as a third independent set:

- keeps each patch set focused (this one is purely an audio HAL
  enumeration fix; not entangled with the 64-bit porting or eGTouchD
  SELinux work);
- makes it easy to apply or skip the USB audio change without
  touching the other two patch sets;
- follows the same `diff/` + `source/` + apply.sh + reset.sh layout
  as `egtouch/`, so the install/verify experience is uniform.

## Verification

After `apply.sh` + a `./build.sh android`, on a booted K2C-tablet
with a USB audio device plugged in:

```bash
adb shell dumpsys media.audio_policy | grep -i usb
# expect: USB Host Out / USB Device Out / USB Headset Out / etc.
# in the devicePorts list, and routes wired from usb_device output
# to USB Device Out / USB Headset Out.

adb shell ls /dev/snd/   # if the kernel's USB-audio driver is loaded
# expect: controlC0 / pcmC0D0c / pcmC0D0p entries
```

Without this patch, the dumpsys output will not list any USB device
port and any USB audio device will be invisible to apps even though
`lsusb` sees it.