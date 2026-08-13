PRODUCT_PLATFORM_PATH := $(shell dirname $(lastword $(MAKEFILE_LIST)))

TARGET_BOARD_IC := h618
PRODUCT_BRAND := Allwinner
PRODUCT_NAME := apollo_p2
PRODUCT_DEVICE := apollo-p2
PRODUCT_BOARD := p2
PRODUCT_MODEL := QUAD-CORE H618 p2
PRODUCT_MANUFACTURER := Allwinner

PRODUCT_PREBUILT_PATH := longan/out/$(TARGET_BOARD_IC)/$(PRODUCT_BOARD)/android
PRODUCT_DEVICE_PATH := $(PRODUCT_PLATFORM_PATH)/$(PRODUCT_DEVICE)

PRODUCT_BUILD_VENDOR_BOOT_IMAGE := true

CONFIG_LOW_RAM_DEVICE := false
CONFIG_SUPPORT_GMS := false
CONFIG_OTA_FROM_10 := false
BOARD_HAS_SECURE_OS := true

PRODUCT_COPY_FILES += $(PRODUCT_PREBUILT_PATH)/bImage:kernel

#set speaker project(true: double speaker, false: single speaker)
#set default eq
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.spk_dul.used=false \
    ro.vendor.audio.eq=false \
    service.adb.tcp.port=5555 \
    persist.sys.bootonDeviceTest=0 \
    persist.sys.boot_count_enabled=0 \
    persist.sys.boot_count=0

PRODUCT_PACKAGES += DragonAtt
PRODUCT_PACKAGES += SoundRecorder
PRODUCT_PACKAGES += FT618

PRODUCT_PACKAGES += \
    tinyplay \
    tinycap \
    tinymix \
    tinypcminfo

# eGalax eGTouch daemon + config files
PRODUCT_PACKAGES += \
    eGTouchD \
    eGTouchA.ini \
    eGalaxTouch_VirtualDevice.idc \
    disable_eeti_raw.sh \
    restart_services.sh

# Stage libstdc++.so and liblog.so into /vendor/lib64 so the dynamic
# linker can resolve them when launching eGTouchD. Declared as
# cc_prebuilt_library_shared modules in
# device/softwinner/apollo/common/eGTouch/Android.bp.
PRODUCT_PACKAGES += \
    libstdc++.eGTouchD \
    liblog.eGTouchD

PRODUCT_PACKAGES += \
    DeviceTest

PRODUCT_COPY_FILES += \
    vendor/aw/homlet/prebuild/DeviceTest/DeviceTestConfig_h618-kickpi-$(KERNEL_DTS)-android.xml:vendor/etc/DeviceTestConfig.xml

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.sys.timezone=Asia/Shanghai \
    persist.sys.country=US \
    persist.sys.language=en

PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=200

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.minui.default_rotation=ROTATION_NONE \
    ro.recovery.ui.touch_high_threshold=60

PRODUCT_HAS_UVC_CAMERA := true

PRODUCT_AAPT_CONFIG := mdpi xlarge hdpi xhdpi large
PRODUCT_AAPT_PREF_CONFIG := mdpi


$(call inherit-product, $(PRODUCT_DEVICE_PATH)/*/config.mk)
$(call inherit-product, $(PRODUCT_PLATFORM_PATH)/common/*/config.mk)
