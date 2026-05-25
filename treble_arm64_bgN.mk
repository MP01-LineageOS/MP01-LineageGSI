TARGET_GAPPS_ARCH := arm64
include build/make/target/product/aosp_arm64.mk
$(call inherit-product, device/phh/treble/base.mk)

$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
$(call inherit-product, device/phh/treble/lineage.mk)
$(call inherit-product, vendor/MP01_services/MP01_services.mk)

PRODUCT_NAME := treble_arm64_bgN
PRODUCT_DEVICE := tdgsi_arm64_ab
PRODUCT_BRAND := Minimal
PRODUCT_SYSTEM_BRAND := Minimal
PRODUCT_MODEL := MP01

# Overwrite the inherited "emulator" characteristics
PRODUCT_CHARACTERISTICS := device

# include inkOS launcher
PRODUCT_PACKAGES += \
    inkos \
    finqwerty \
    F-DroidPrivilegedExtension

PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true # jank - for inkOS

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.system.treble.presets=https://raw.githubusercontent.com/MP01-LineageOS/treble_presets/09fdae135930b553c54aba7aa9a07b105132b6ff/infos.json

LINEAGE_BUILDTYPE := GAPPS
LINEAGE_BUILD := GSI

#EROFS
#LINEAGE_EXTRAVERSION := -EROFS
#GSI_FILE_SYSTEM_TYPE := erofs
#BOARD_EROFS_COMPRESSOR := lz4hc,9
LINEAGE_EXTRAVERSION := -EXT4
PRODUCT_EXTRA_VNDK_VERSIONS += 28 29
TARGET_PRODUCT_PROP += device/phh/treble/product.prop
#EXT4
#LINEAGE_EXTRAVERSION := -EXT4
#PRODUCT_EXTRA_VNDK_VERSIONS += 28 29
