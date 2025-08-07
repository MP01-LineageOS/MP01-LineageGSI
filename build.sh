#!/bin/bash

export USE_CCACHE=1
export CCACHE_DIR=~/.cache/ccache
export CCACHE_EXEC=$(which ccache)
ccache -M 200G

mkdir -p ~/los22
cd ~/los22

repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs

rm -r .repo/local_manifests
mkdir -p .repo/local_manifests
git clone https://github.com/chardidathing/treble_manifest.git .repo/local_manifests -b 15-los-qpr2

# this is destructive, but :shrug:
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune --force-checkout --force-remove-dirty -j8

# Apply TrebleDroid patches
cd ~/los22
bash ~/los22/MP01Support/patches/apply-patches.sh .

# Generate treble makefiles
cd ~/los22/device/phh/treble
bash generate.sh lineage

# Copy MP01 specific makefiles and vendor additions into vendor
cp ~/los22/MP01Support/treble_arm64* ~/los22/device/phh/treble/
cp -r ~/los22/MP01Support/vendor ~/los22/vendor/

# Do tha thing
source ~/los22/build/envsetup.sh
lunch treble_arm64_bvN-bp1a-userdebug
make systemimage -j$(nproc --all)
