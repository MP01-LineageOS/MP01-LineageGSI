#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(cd "$script_dir/.." && pwd)"
workspace_build_dir="${MP01_WORKSPACE_BUILD_DIR:-$workspace_dir/.android-build}"
build_root="${MP01_BUILD_ROOT:-$workspace_build_dir/los22-microg}"
image_dir="${MP01_IMAGE_DIR:-$workspace_dir/images}"
export CCACHE_DIR="${CCACHE_DIR:-${MP01_CCACHE_DIR:-$workspace_build_dir/ccache}}"
export CCACHE_EXEC="${CCACHE_EXEC:-$(command -v ccache || true)}"
manifest_repo_override="${MP01_MANIFEST_REPO+x}"
support_repo_override="${MP01_SUPPORT_REPO+x}"
source "$script_dir/scripts/release-inputs.sh"
manifest_repo="$MP01_MANIFEST_REPO"
manifest_branch="$MP01_MANIFEST_BRANCH"
support_repo="$MP01_SUPPORT_REPO"
support_branch="$MP01_SUPPORT_BRANCH"
min_free_gb="${MP01_MIN_FREE_GB:-400}"
export CODEX_WORKSPACE_DIR="${CODEX_WORKSPACE_DIR:-$workspace_dir}"
export CODEX_ALLOW_NON_WORKSPACE_LARGE_STATE="${MP01_ALLOW_NON_WORKSPACE_BUILD:-${CODEX_ALLOW_NON_WORKSPACE_LARGE_STATE:-0}}"

workspace_paths_helper="${CODEX_HOME:-$HOME/.codex}/lib/codex_container/workspace_paths.sh"
if [[ -f "$workspace_paths_helper" ]]; then
    source "$workspace_paths_helper"
else
    echo "ERROR: Missing Codex workspace path helper: $workspace_paths_helper" >&2
    echo "Run this script through /Users/j/.codex/bin/codex-in-container after redeploying the container system." >&2
    exit 1
fi

if [[ -z "$manifest_repo_override" && -d "$script_dir/../treble_manifest/.git" ]]; then
    manifest_repo="$(cd "$script_dir/../treble_manifest" && pwd)"
fi

if [[ -z "$support_repo_override" ]]; then
    support_repo="$script_dir"
    support_branch=""
fi

codex_require_large_state_path "$workspace_build_dir" "workspace build directory"
codex_require_large_state_path "$build_root" "Android build root"
codex_require_large_state_path "$CCACHE_DIR" "ccache directory"
codex_require_large_state_path "$image_dir" "image output directory"

mkdir -p "$workspace_build_dir" "$build_root" "$image_dir"

if [[ -n "${CCACHE_EXEC}" ]]; then
    export USE_CCACHE=1
    mkdir -p "$CCACHE_DIR"
    ccache -M 200G
fi

codex_check_free_space_gib "$workspace_build_dir" "$min_free_gb"
mp01_ensure_repo_launcher "$build_root/.bin"
cd "$build_root"

repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs -g default,microg

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
git clone --depth 1 --branch "$manifest_branch" "$manifest_repo" .repo/local_manifests

cat > .repo/local_manifests/zz_mp01_microg.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remove-project name="MisterZtr/vendor_gapps" />
    <remove-project name="privileged-extension.git" />
</manifest>
EOF

# This build root is intentionally variant-specific and can be force-synced.
repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune --force-checkout --force-remove-dirty -j8

if [[ -d vendor/gapps ]]; then
    echo "ERROR: vendor/gapps is present in the microG build graph." >&2
    exit 1
fi

if [[ -d vendor/F-DroidPrivilegedExtension ]]; then
    echo "ERROR: standalone F-DroidPrivilegedExtension is present in the microG build graph." >&2
    exit 1
fi

if [[ ! -d vendor/partner_gms ]]; then
    echo "ERROR: vendor/partner_gms was not synced. Check manifest groups." >&2
    exit 1
fi

rm -rf MP01Support
if [[ -n "$support_branch" ]]; then
    git clone --depth 1 --branch "$support_branch" "$support_repo" MP01Support
else
    git clone "$support_repo" MP01Support
fi

# Apply TrebleDroid and MP01 patches.
rm -rf patches
cp -R MP01Support/patches patches
bash patches/apply-patches.sh "$build_root"
rm -rf patches

# Generate TrebleDroid makefiles, then replace the MP01 targets explicitly.
cd device/phh/treble
bash generate.sh lineage
rm -f treble_arm64*
cp "$build_root"/MP01Support/treble_arm64* .
cp "$build_root"/MP01Support/AndroidProducts.mk .
cd "$build_root"

# Copy MP01 vendor additions into the Android tree.
mkdir -p vendor
cp -R MP01Support/vendor/. vendor/
rm -rf MP01Support

mp01_download_finqwerty_apk "vendor/finqwerty/$MP01_FINQWERTY_APK_NAME"

bash vendor/partner_gms/vendorsetup.sh

expected_microg_apks=(
    vendor/partner_gms/GmsCore/GmsCore.apk
    vendor/partner_gms/FakeStore/FakeStore.apk
    vendor/partner_gms/GsfProxy/GsfProxy.apk
    vendor/partner_gms/FDroid/FDroid.apk
    vendor/partner_gms/FDroidPrivilegedExtension/FDroidPrivilegedExtension.apk
)

for apk in "${expected_microg_apks[@]}"; do
    if [[ ! -f "$apk" ]]; then
        echo "ERROR: Missing expected microG APK: $apk" >&2
        exit 1
    fi
done

source build/envsetup.sh
lunch treble_arm64_bmN-bp1a-userdebug

make target-files-package otatools -j"$(nproc --all)"

build_date=$(date +%s)
image_filename="MP01-Lineage-${build_date}-microG-unsigned.img"
tar_filename="MP01-Lineage-${build_date}-microG-unsigned.tar.gz"
image_path="$image_dir/$image_filename"
tar_path="$image_dir/$tar_filename"

if [[ ! -f "$OUT/system.img" ]]; then
    echo "ERROR: System image file not found: $OUT/system.img" >&2
    exit 1
fi

mkdir -p "$image_dir"
cp "$OUT/system.img" "$image_path"
tar -czvf "$tar_path" -C "$image_dir" "$image_filename"

echo "Build completed successfully."
echo "Image file: $image_path"
echo "Archive file: $tar_path"
echo "Signing status: unsigned local test image"
