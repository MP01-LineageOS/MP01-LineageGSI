TARGET_GAPPS_ARCH := arm64
include build/make/target/product/aosp_arm64.mk
$(call inherit-product, device/phh/treble/base.mk)

WITH_GMS := true
$(call inherit-product, vendor/partner_gms/products/gms.mk)
$(call inherit-product, device/phh/treble/lineage.mk)
$(call inherit-product, vendor/MP01_services/MP01_services.mk)

PRODUCT_NAME := treble_arm64_bmN
PRODUCT_DEVICE := tdgsi_arm64_ab
PRODUCT_BRAND := Minimal
PRODUCT_SYSTEM_BRAND := Minimal
PRODUCT_MODEL := MP01

# Overwrite the inherited "emulator" characteristics
PRODUCT_CHARACTERISTICS := device

# include MP01-specific apps
PRODUCT_PACKAGES += \
    inkos \
    finqwerty

PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true # jank - for inkOS

# inkOS is set as the default launcher - idk if this is right
#PRODUCT_PROPERTY_OVERRIDES += \
#    ro.launcher.home=app.inkos
# this seems to break things??

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
	ro.system.ota.json_url=https://raw.githubusercontent.com/MP01-LineageOS/MP01-LineageGSI/15/ota.json

LINEAGE_BUILDTYPE := MICROG
LINEAGE_EXTRAVERSION := -MICROG-EXT4
LINEAGE_BUILD := GSI
PRODUCT_EXTRA_VNDK_VERSIONS += 28 29
