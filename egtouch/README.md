# h618-patches

Patches and binaries for the Allwinner H618 (apollo-p2, k2c-tablet) Android
12.0 build that wire up:

1. **eGalax eGTouchD** — vendor touch daemon (the firmware-side driver for
   the eGalax resistive touch panel).
2. **eGalaxCalibrator** — the matching calibration APK, pre-installed as
   a system app so the calibration tool is reachable from the launcher.
3. **Serial / GPIO / resistive-touch node permissions** — so a debug APK
   running as a normal release build can read the on-board UARTs and
   talk to the GPIO chip without needing root.
4. **SELinux adjustments** — vendor domain (eGTouchD) plus the SELinux
   type and policy holes needed for the daemon and the calibration
   APK to coexist with Android 12 (API 31) Treble.

These are the result of the in-chat debug session, packaged so they can be
re-applied verbatim after `git reset --hard` or a clean rebase.

---

## Layout

```
h618-patches/
├── apply.sh            # one-shot installer (idempotent — refuses to run on a dirty tree)
├── reset.sh            # nukes everything apply.sh puts down
├── README.md           # this file
├── diff/               # `git diff` outputs, 5 patches in apply order
│   ├── 00-board-swap.diff        # .BoardConfig.mk + sys_config.fex
│   ├── 01-egtouch-binary.diff   # apollo_p2.mk + init.sun50iw9p1.rc
│   ├── 02-egtouch-apk.diff      # homlet.mk (the eGalaxCalibrator PRODUCT_PACKAGES line)
│   ├── 04-system-sepolicy.diff  # system/sepolicy/{public,prebuilts/api/31.0}/...
│   └── 05-uart-gpio.diff        # file_contexts + untrusted_app.te
├── source/             # untracked source-tree additions (mirrored into the tree)
│   ├── device/softwinner/apollo/common/eGTouch/
│   │   ├── Android.bp            # cc_prebuilt_library_shared for libstdc++.eGTouchD & liblog.eGTouchD
│   │   ├── Android.mk            # prebuilt modules for eGTouchD, eGTouchA.ini, eGalaxTouch_VirtualDevice.idc
│   │   ├── eGTouchD              # populated by apply.sh from binaries/
│   │   ├── eGTouchA.ini          # ditto
│   │   ├── eGalaxTouch_VirtualDevice.idc  # ditto
│   │   ├── libstdc++.eGTouchD.so # ditto — SONAME-patched via patchelf
│   │   └── liblog.eGTouchD.so    # ditto
│   ├── device/softwinner/common/sepolicy/vendor/egtouchd.te
│   └── vendor/aw/homlet/prebuild/eGalaxCalibrator/
│       ├── Android.mk            # prebuilt module for the APK
│       └── eGalaxCalibrator.apk  # populated by apply.sh from binaries/
└── binaries/           # raw payload files (gitignored; tarballable separately)
    ├── eGTouchD
    ├── eGTouchA.ini
    ├── eGalaxTouch_VirtualDevice.idc
    ├── libstdc++.eGTouchD.so
    ├── liblog.eGTouchD.so
    └── eGalaxCalibrator.apk
```

---

## Apply

```bash
cd /path/to/h618-android12.0       # the Android source root
~/h618-patches/apply.sh            # refuses to run on a dirty tree
./build.sh android
```

`apply.sh` is idempotent — it short-circuits with `git diff --quiet HEAD` so
it won't overwrite a hand-edited tree. Pass `--force` to skip that check.

If the tree is dirty, run `~/h618-patches/reset.sh` first to drop the
patches, then `git reset --hard HEAD` to throw away any hand edits, then
re-run `apply.sh`.

## Revert

```bash
cd /path/to/h618-android12.0
~/h618-patches/reset.sh           # reverts tracked files + deletes untracked additions
git reset --hard HEAD             # optional: throw away any hand edits to the reverted files
```

`reset.sh` does **not** delete the binary files in `binaries/` — those
are the source of truth and stay put.

---

## What each patch does

### 00-board-swap — board / softwinner config
- Switches `device/softwinner/.BoardConfig.mk` from `k2b` to `k2c` (the
  k2c-tablet board is the H618 target).
- Re-points `longan/device/config/chips/h618/configs/p2/sys_config.fex`
  at `device/softwinner/sys_config-k2c.fex`.

If your build is already on k2c, the diff applies as a no-op.

### 01-egtouch-binary — eGTouchD packaging + init service + excluded-input-devices.xml
- `device/softwinner/apollo/apollo_p2.mk` — adds `eGTouchD`,
  `eGTouchA.ini`, `eGalaxTouch_VirtualDevice.idc`, `excluded-input-devices.xml`
  to PRODUCT_PACKAGES.
- `device/softwinner/apollo/common/eGTouch/excluded-input-devices.xml` —
  suppresses the kernel's built-in `hid-multitouch` input nodes (`eGalax Inc. USB TouchController...`)
  so Android EventHub only receives touch events from `eGTouchD`'s virtual device (`uinput`),
  preventing duplicate input drop / permission denied errors in InputDispatcher.
- `device/softwinner/apollo/common/system/init.sun50iw9p1.rc` — in
  `post-fs-data`: mkdir `/data/eGalax` (0777), copy `/vendor/etc/eGTouchA.ini`
  to `/data/eGTouchA.ini`, create the two FIFOs
  (`egalax_tool_in`, `egalax_tool_out`), and `restorecon` their labels.
  Declares `service egtouchd /vendor/bin/eGTouchD -f` as `user root` with
  `seclabel u:r:egtouchd:s0` and starts it from `on boot_completed=1`.


### 02-egtouch-apk — eGalaxCalibrator
- `vendor/aw/homlet/homlet.mk` — adds `eGalaxCalibrator` to PRODUCT_PACKAGES.
- `vendor/aw/homlet/prebuild/eGalaxCalibrator/Android.mk` — prebuilt
  module that installs the APK to `/system/priv-app` and re-signs it with
  the platform key (see note below).

The APK is re-signed with the platform key because `eGTouchD` rejects
untrusted_app connections. The EETI original signature is preserved
inside the APK; re-signing only changes the outer wrapper.

### 04-system-sepolicy — platform SELinux changes
- `system/sepolicy/public/file.te` and `prebuilts/api/31.0/public/file.te`
  declare `egtouchd`, `egtouchd_exec`, `egalax_data_file` so the
  platform-side neverallow rules can reference them.
- `system/sepolicy/public/domain.te` adds `-egtouchd` to the whitelist
  of the two `core_data_file_type` neverallow rules at lines 829 and
  859.
- `system/sepolicy/private/compat/{26.0..30.0}/*.ignore.cil` and the
  matching prebuilt copies add `egtouchd`, `egtouchd_exec`,
  `egalax_data_file` to the `new_objects` attribute so the
  treble-sepolicy compatibility tests still pass.

### 05-uart-gpio — debug permissions for APK
- `device/softwinner/apollo/common/system/ueventd.sun50iw9p1.rc` —
  chmod 0666 the `/dev/ttyS*`, `/dev/ttyAS*`, `/dev/gpiochip*` and
  `/sys/class/gpio/{export,unexport,gpioN/{direction,value,edge,active_low}}`
  so a normal debug APK can read and write them.
- `device/softwinner/common/sepolicy/vendor/file_contexts` — labels the
  above sysfs and chardev nodes so the perms are enforced.
- `device/softwinner/common/sepolicy/vendor/untrusted_app.te` — lets
  `untrusted_app` open `serial_device:chr_file` for read/write/ioctl.

NB: `sysfs:file` writes are forbidden by Android itself (no amount of
vendor policy bypasses `neverallow coredomain sysfs:file no_rw_file_perms`),
so a debug APK cannot directly write GPIO values via sysfs. The 0666
permission on the chardev nodes (`/dev/gpiochipN`) is what lets a normal
APK use libgpiod to drive GPIOs.

---

## Why the eGTouchD .so files are renamed

eGTouchD is dynamically linked to `libstdc++.so` and `liblog.so` (system
soname). Sticking them in `/vendor/lib64` directly would have the
build system reject the ELF (the soname doesn't match the file name)
and would also clash with the same files in `/system/lib64`.

The fix is to patch the SONAME of each shared library to a unique name
(`libstdc++.eGTouchD.so`, `liblog.eGTouchD.so`) and patch the DT_NEEDED
list of `eGTouchD` so it looks for the renamed names. The build-system
integration is in `source/device/softwinner/apollo/common/eGTouch/Android.bp`
(`cc_prebuilt_library_shared`).

If you ever need to redo the patching:

```bash
patchelf --set-soname libstdc++.eGTouchD.so /path/to/libstdc++.eGTouchD.so
patchelf --set-soname liblog.eGTouchD.so    /path/to/liblog.eGTouchD.so
patchelf --replace-needed libstdc++.so libstdc++.eGTouchD.so /path/to/eGTouchD
patchelf --replace-needed liblog.so    liblog.eGTouchD.so    /path/to/eGTouchD
```

---

## Why eGTouchD is started as root

Strings inside the binary:

```
Errot: Permission is not root. Please execute driver with root permission!
```

The `-f` daemon mode just won't enter the endless-scan loop without root.
We start it as `user root` from init — the alternative is to hack the
binary to drop the geteuid() check, which is much more invasive.

---

## Verification

```bash
adb shell ls -l /vendor/bin/eGTouchD /vendor/lib64/lib*.eGTouchD.so
adb shell ls -l /system/priv-app/eGalaxCalibrator/
adb shell ls -l /data/eGalax/          # expect egalax_tool_in / egalax_tool_out
adb shell ps -A | grep eGTouchD       # expect a running process
adb shell am start -n com.eeti.android.egalaxcalibrator/.eGalaxCalibrator
# touch the screen — calibration UI should respond
adb logcat -d | grep -i 'egtouchd\|egalax' | tail -50
```
