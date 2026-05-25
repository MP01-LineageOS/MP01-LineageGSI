TARGET_GAPPS_ARCH := arm64
include build/make/target/product/aosp_arm64.mk
$(call inherit-product, device/phh/treble/base.mk)

$(call inherit-product, device/phh/treble/lineage.mk)
$(call inherit-product, vendor/MP01_services/MP01_services.mk)

PRODUCT_NAME := treble_arm64_bvN
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
    ro.system.ota.json_url=https://raw.githubusercontent.com/MP01-LineageOS/MP01-LineageGSI/15/ota.json \
    ro.system.treble.presets=https://raw.githubusercontent.com/MP01-LineageOS/treble_presets/09fdae135930b553c54aba7aa9a07b105132b6ff/infos.json

LINEAGE_BUILDTYPE := VANILLA
LINEAGE_EXTRAVERSION := -EXT4
LINEAGE_BUILD := GSI
PRODUCT_EXTRA_VNDK_VERSIONS += 28 29
