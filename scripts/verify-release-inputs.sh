#!/bin/bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/release-inputs.sh"

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [download-directory]" >&2
    exit 2
fi

created_tmp=0
download_dir="${1:-}"
if [[ -z "$download_dir" ]]; then
    download_dir="$(mktemp -d)"
    created_tmp=1
fi

cleanup() {
    if [[ "$created_tmp" -eq 1 ]]; then
        rm -rf "$download_dir"
    fi
}
trap cleanup EXIT

mkdir -p "$download_dir"

mp01_download_finqwerty_apk "$download_dir/$MP01_FINQWERTY_APK_NAME"
mp01_download_fdroid_apk "$download_dir/$MP01_FDROID_APK_NAME"
mp01_download_treble_presets "$download_dir/$MP01_TREBLE_PRESETS_NAME"

mp01_require_tool python3
python3 -m json.tool "$download_dir/$MP01_TREBLE_PRESETS_NAME" >/dev/null

echo "Verified pinned MP01 release inputs:"
echo "  FinQwerty: $MP01_FINQWERTY_VERSION"
echo "  F-Droid: $MP01_FDROID_VERSION"
echo "  Treble presets: $MP01_TREBLE_PRESETS_COMMIT"
