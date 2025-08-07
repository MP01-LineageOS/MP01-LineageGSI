#!/bin/bash

export USE_CCACHE=1
export CCACHE_DIR=~/.cache/ccache
export CCACHE_EXEC=$(which ccache)
ccache -M 200G

mkdir -p ~/los22
cd ~/los22

repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs

mkdir -p .repo/local_manifests
git clone https://github.com/chardidathing/treble_manifest.git .repo/local_manifests -b 15-los-qpr2

# this is destructive, but :shrug:
if ! repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j8; then
    echo "repo sync failed."
    read -p "Do you want to run 'git reset --hard' on all repos to try and fix the issue? [y/N]: " yn
    case "$yn" in
        [Yy]* )
            repo forall -vc "git reset --hard"
            repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j8
            ;;
        * )
            echo "Skipping git reset. Exiting."
            exit 1
            ;;
    esac
fi

bash ~/los22/MP01Support/patches/apply-patches.sh .

cd ~/los22/device/phh/treble
bash generate.sh lineage

cp ~/los22/MP01Support/treble_arm64* ~/los22/device/phh/treble/
cp -r ~/los22/MP01Support/vendor ~/los22/vendor/

source ~/los22/build/envsetup.sh
lunch treble_arm64_bvN-bp1a-userdebug
make systemimage -j$(nproc --all)
