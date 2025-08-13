#!/bin/bash

# Check if android-certs directory exists
if [[ ! -d ~/.android-certs ]]; then
    echo "Error: ~/.android-certs directory not found!"
    echo "Please ensure you have set up your Android signing keys in ~/.android-certs"
    echo "This directory should contain your releasekey and other signing certificates."
    exit 1
fi

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
cp -r ~/los22/MP01Support/vendor/inkos ~/los22/vendor/ # copy inkOS - TODO: Replace with our own built version like finqwerty
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

curl -L -o ~/los22/vendor/finqwerty/finqwerty-release.apk "$finqwerty_download_url"

# Validate APK using aapt if available
if command -v aapt >/dev/null 2>&1; then
    if ! aapt dump badging ~/los22/vendor/finqwerty/finqwerty-release.apk >/dev/null 2>&1; then
        echo "ERROR: Downloaded file is not a valid APK (aapt validation failed)"
        exit 1
    fi
    echo "APK validation successful"
fi

# Fetch F-Droid apk
curl -L -o ~/los22/vendor/F-Droid/F-Droid.apk "https://f-droid.org/F-Droid.apk"

# Verify F-Droid APK signature using keytool
fdroid_sha256="43:23:8D:51:2C:1E:5E:B2:D6:56:9F:4A:3A:FB:F5:52:34:18:B8:2E:0A:3E:D1:55:27:70:AB:B9:A9:C9:CC:AB"
fdroid_apk_path="~/los22/vendor/F-Droid/F-Droid.apk"

if command -v keytool >/dev/null 2>&1; then
    fd_reported_sha256=$(keytool -printcert -jarfile ~/los22/vendor/F-Droid/F-Droid.apk 2>/dev/null | awk -F': ' '/SHA256:/ {gsub(/ /,"",$2); for(i=1;i<=length($2);i+=2) printf "%s:", substr($2,i,2); print ""}' | sed 's/:$//' | tr 'a-f' 'A-F' | head -n1)
    # Remove trailing colon if present
    fd_reported_sha256="${fd_reported_sha256%:}"
    if [[ "$fd_reported_sha256" != "$expected_sha256" ]]; then
        echo "ERROR: F-Droid APK SHA256 does not match expected value!"
        echo "Expected: $expected_sha256"
        echo "Actual:   $fd_reported_sha256"
        exit 1
    fi
    echo "F-Droid APK SHA256 signature matches expected value."
else
    echo "WARNING: keytool not found, cannot verify F-Droid APK signature."
fi

# Do tha thing
source ~/los22/build/envsetup.sh
if ! lunch treble_arm64_bvN-bp1a-userdebug; then
  exit 1
fi

# Build both system image and target files package
if ! make target-files-package otatools -j$(nproc --all); then
  exit 1
fi

# Get current date in human readable format
current_date=$(date '+%Y-%m-%d')
# Get current timestamp
build_date=$(date +%s)
echo "Packing and signing system image... build_date is ${build_date}"
cd ~/MP01-LineageGSI

echo "Building signed build (release-keys)"
tar_filename="MP01-Lineage-${build_date}-signed.tar.gz"
image_filename="MP01-Lineage-${build_date}-signed.img"

# For signed builds, use the signing process
echo "Signing target files package..."
cd ../los22

# Sign the target files package using sign.sh script
if ! bash ~/MP01-LineageGSI/sign.sh "signed-target-files-${build_date}.zip"; then
    echo "Signing failed!"
    exit 1
fi

# Generate the signed OTA package
echo "Generating signed OTA package..."
if ! ota_from_target_files -k ~/.android-certs/releasekey \
    --block --backup=true \
    "signed-target-files-${build_date}.zip" \
    "signed-ota-update-${build_date}.zip"; then
    echo "OTA generation failed!"
    exit 1
fi

# Extract the signed system image from the signed target files package
echo "Extracting signed system image..."
cd ~/MP01-LineageGSI

# Extract system.img from the signed target files package
if unzip -j "../los22/signed-target-files-${build_date}.zip" "IMAGES/system.img" -d . 2>/dev/null; then
    echo "Successfully extracted system.img from signed target files"
    mv system.img "$image_filename"
else
    echo "Error: Could not extract system.img from signed target files package"
    echo "Available files in signed target files package:"
    unzip -l "../los22/signed-target-files-${build_date}.zip"
    exit 1
fi

# Verify the image file exists before proceeding
if [[ ! -f "$image_filename" ]]; then
    echo "Error: System image file not found: $image_filename"
    exit 1
fi

# Clean up intermediate files
# rm -f "../los22/signed-target-files-${build_date}.zip"
# rm -f "../los22/signed-ota-update-${build_date}.zip"

# Create tar.gz with the image file
tar -czvf "$tar_filename" "$image_filename"

# Upload to GitHub releases
gh release create "${build_date}" --title "system-${build_date}" --notes "System Image for MP01" -d
gh release upload "${build_date}" "$tar_filename"

# Update OTA file, commit, and push to repo
echo "Updating OTA file, committing, and pushing to repo..."
cd ~/MP01-LineageGSI
git pull # pull latest changes - fixes issue being unable to commit ota.json 

# Get the size of the tar.gz file in bytes
tar_size=$(stat -c%s "$tar_filename")

# Update ota.json with new build information
cat > ota.json << EOF
{
    "version": "${current_date} (LineageOS 22.2)",
    "date": "${build_date}",
    "variants": [
        {
            "name": "treble_arm64_bvN",
            "size": "${tar_size}",
            "url": "https://github.com/MP01Experiments/MP01-LineageGSI/releases/download/${build_date}/${tar_filename}"
        }
    ]
}
EOF

# Commit and push the updated ota.json
git add ota.json
git commit -m "Update OTA.json for build ${build_date} (${current_date})"
git push

echo "Build completed successfully!"
echo "Output file: $tar_filename"
echo "Signing status: signed"
