# eGalax eGTouch daemon and config — packaged for /vendor and /data
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

# eGTouchD daemon (aarch64). Installed into /vendor/bin/eGTouchD.
# libstdc++.so and liblog.so are also staged into /vendor/lib64 by the
# Android.bp modules declared at the bottom of this directory, so the
# dynamic linker can resolve them when launching eGTouchD.
LOCAL_MODULE := eGTouchD
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/bin
LOCAL_SRC_FILES := eGTouchD
LOCAL_MODULE_TAGS := optional
# eGTouchD's DT_NEEDED was patched via patchelf to depend on the
# renamed SONAMEs "libstdc++.eGTouchD" and "liblog.eGTouchD", not
# the system-provided libstdc++.so / liblog.so. The corresponding
# prebuilt modules live in Android.bp below.
LOCAL_SHARED_LIBRARIES := libstdc++.eGTouchD liblog.eGTouchD
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)

# eGTouchA.ini — the daemon reads /data/eGTouchA.ini (per its own NOTE)
# We stage a copy at /vendor/etc/eGTouchA.ini and have init.rc copy it to /data
# at post-fs-data time so users can override it via adb push.
LOCAL_MODULE := eGTouchA.ini
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/etc
LOCAL_SRC_FILES := eGTouchA.ini
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)

# eGalaxTouch_VirtualDevice.idc — picked up by Android InputReader.
# Place under /vendor/usr/idc so it is honored by the framework.
LOCAL_MODULE := eGalaxTouch_VirtualDevice.idc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/usr/idc
LOCAL_SRC_FILES := eGalaxTouch_VirtualDevice.idc
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)

# excluded-input-devices.xml — suppresses the kernel's built-in hid-multitouch
# input devices for the EETI USB touch panel (VID=0eef PID=0001) so Android's
# EventHub only binds to the eGTouchD virtual devices created via uinput.
LOCAL_MODULE := excluded-input-devices.xml
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/etc
LOCAL_SRC_FILES := excluded-input-devices.xml
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)

