# Copyright (C) 2024 The Android Open Source Project
#
# Pre-installed eGalaxCalibrator (vendor tool) — installed to /system/priv-app
# with the platform signing certificate.
#
# Rationale: the eGalax eGTouch daemon (eGTouchD) is a vendor socket service.
# In Android 10+ (Treble), the neverallow rules
#   * appdomain socket_device:sock_file write
#   * neverallow_establish_socket_comms({coredomain},{vendor socket})
# forbid untrusted_app from opening the daemon's sock_file or connecting to
# the daemon's unix socket. By signing this app with the platform key and
# installing it under /system/priv-app, it joins the priv_app domain which
# is not subject to those neverallows.
#
# Note: the ORIGINAL APK is signed by EETI. Re-signing with platform key
# means eGTouchD will see this app with a different signing identity.
# If eGTouchD's signature whitelist does not include the platform key, the
# APK will fail to authenticate against the daemon. We keep the original APK
# as the source and rely on the build system to re-sign it.
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)

# Re-sign with the platform key and install under /system/priv-app so the
# resulting package runs in the priv_app SELinux domain.
LOCAL_CERTIFICATE := platform
LOCAL_PRIVILEGED_MODULE := true

LOCAL_MODULE := eGalaxCalibrator
LOCAL_SRC_FILES := eGalaxCalibrator.apk

include $(BUILD_PREBUILT)