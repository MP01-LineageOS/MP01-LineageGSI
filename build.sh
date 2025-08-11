#!/bin/bash

export USE_CCACHE=1
export CCACHE_DIR=~/.cache/ccache
export CCACHE_EXEC=$(which ccache)
ccache -M 200G

mkdir -p ~/los22
cd ~/los22

repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
git clone https://github.com/MP01Experiments/treble_manifest.git .repo/local_manifests -b 15-los-qpr2

# this is destructive, but :shrug:
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune --force-checkout --force-remove-dirty -j8

git clone https://github.com/MP01Experiments/MP01-LineageGSI.git MP01Support

# Apply TrebleDroid patches
cp -r ~/los22/MP01Support/patches ~/los22/patches
cd ~/los22
bash ~/los22/MP01Support/patches/apply-patches.sh ~/los22
rm -rf ~/los22/patches

# Generate treble makefiles
cd ~/los22/device/phh/treble
bash generate.sh lineage
cd ~/los22

# Copy MP01 specific makefiles and vendor additions into vendor
rm ~/los22/device/phh/treble/treble_arm64* # remove old makefiles
cp ~/los22/MP01Support/treble_arm64* ~/los22/device/phh/treble/ # copy new makefiles
cp -r ~/los22/MP01Support/vendor ~/los22/ # copy vendor
cp -r ~/los22/MP01Support/vendor/inkOS ~/los22/vendor/ # copy inkOS - TODO: Replace with our own built version like finqwerty
cp -r ~/los22/MP01Support/vendor/finqwerty ~/los22/vendor/ # create finqwerty folder with Android.bp in it
rm -rf ~/los22/MP01Support # Cleanup before build to prevent build errors

# Download latest finqwerty apk
finqwerty_apk="finqwerty-release.apk" # this will always stay the same

# Fetch latest release JSON and extract download URL for the asset
finqwerty_download_url=$(curl -s https://api.github.com/repos/MP01Experiments/finqwerty/releases/latest \
  | jq -r --arg NAME "$finqwerty_apk" '.assets[] | select(.name == $NAME) | .browser_download_url')

if [[ -z "$finqwerty_download_url" || "$finqwerty_download_url" == "null" ]]; then
  echo "Asset $finqwerty_apk not found in latest release." >&2
  exit 1
fi

curl -L -o ~/los22/vendor/finqwerty/finqwerty-release.apk "$finqwerty_download_url" # Download latest release and dump in vendor/finqwerty

# Do tha thing
source ~/los22/build/envsetup.sh
if ! lunch treble_arm64_bvN-bp1a-userdebug; then
  exit 1
fi
if ! make systemimage -j$(nproc --all); then
  exit 1
fi

build_date=$(date +%s)
echo "Packing system image... build_date is ${build_date}"
cd ~/MP01-LineageGSI
cp ../los22/out/target/product/tdgsi_arm64_ab/system.img "system.img"
tar -czvf "system-${build_date}.tar.gz" ./system.img

gh release create "${build_date}" --title "system-${build_date}" --notes "System Image for MP01" -d
gh release upload "${build_date}" "system-${build_date}.tar.gz"

# Update OTA file and commit to repo
echo "Updating OTA file and committing to repo..."
cd ~/MP01-LineageGSI

# Get current date in human readable format
current_date=$(date '+%Y-%m-%d')
# Get current timestamp
current_timestamp=$(date +%s)
# Get the size of the tar.gz file in bytes
tar_size=$(stat -c%s "system-${build_date}.tar.gz")

# Update ota.json with new build information
cat > ota.json << EOF
{
    "version": "${current_date} (LineageOS 22.2)",
    "date": "${current_timestamp}",
    "variants": [
        {
            "name": "treble_arm64_bvN-userdebug",
            "size": "${tar_size}",
            "url": "https://github.com/MP01Experiments/MP01-LineageGSI/releases/download/${build_date}/system-${build_date}.tar.gz"
        }
    ]
}
EOF
