## LineageOS 22.2 GSI for Minimal Phone (MP01)
You'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [TrebleDroid Wiki](https://github.com/TrebleDroid/treble_experimentations/wiki).

For known issues, bug reports, and future features see the project [issues](https://github.com/MP01-LineageOS/MP01-OS/issues).

### Display Notes
> Currently I'm testing using v25 of the screen firmware, I'll include a way to migrate between builds at some point. I'll also provide a side-by-side so you can pick which version suits you the best.

### Resources
- [Dumbphone Hangout Discord](https://discord.gg/Emt3jwUMg9) - I'll be posting updates in the #mp01-lineage-updates channel
- [Minimal Phone MP01 Unlock & Flashing Guide](https://chardidath.ing/posts/mp01-flashing-guide/)

### Device Defaults Status

| Default | Owner | Status |
| --- | --- | --- |
| Physical keyboard | `vendor/MP01_services/mp_keyboard` | Installed into `system/usr`; no manual FinQwerty layout selection should be needed when these files are present. |
| Default launcher | SetupWizard patch in this repo | SetupWizard assigns inkOS as home and launches `app.inkos/com.github.gezimos.inkos.MainActivity`. |
| Light theme | `MP01AccessibilityService` | First normal boot seeds `ui_night_mode=1` before setup completes. Existing configured phones are not overwritten unless `persist.mp01.defaults.force=1`. |
| PHH presets | `treble_app` and `treble_presets` | MP01 products point at a pinned `MP01-LineageOS/treble_presets` `infos.json`. Verify with `scripts/verify-release-inputs.sh`. |
| IMS defaults | `treble_presets` and `vendor_hardware_overlay` | Inventoried only in this pass. Radio-sensitive IMS behavior needs device testing before more changes. |
| E-ink refresh tuning | `MP01AccessibilityService` | Still manual. Per-app refresh behavior needs device testing before changing defaults. |

### Build Script (Testing)
```bash
git clone https://github.com/MP01-LineageOS/MP01-LineageGSI.git -b 15
cd MP01-LineageGSI
bash scripts/verify-release-inputs.sh
bash build.sh
```

### Release Inputs
Downloaded release inputs are pinned in `scripts/release-inputs.sh`. Update the
URL, version, and SHA256 together when intentionally moving to a new FinQwerty,
F-Droid, Treble presets, repo-launcher, or baseline release artifact.

Verify the pinned inputs without a full Android checkout:

```bash
bash scripts/verify-release-inputs.sh
```
<details>
    <summary>Manual Build Instructions (Incomplete)</summary>

    ### Create the directories

    As a first step, you'll have to create and enter a folder with the appropriate name
    To do that, run these commands:

    ```bash
    mkdir LineageOS
    cd LineageOS
    ```

    ### To initialize your local repository, run this command:

    ```bash
    repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs
    ```
    

    ### Clone the Manifest to add necessary dependencies for gsi:
    
        git clone https://github.com/MP01-LineageOS/treble_manifest.git .repo/local_manifests -b 15-los-qpr2
    


    ### Afterwards, sync the source by running this command:

    ```bash
    repo sync --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j4
    ```


    ### Next, apply patches:

    Copy the patches folder to rom folder and in rom folder

    ```
    bash patches/apply-patches.sh .
    ```

    ## Generating Rom Makefile

    Clone this repository, and then in device/phh/treble folder, run following commands:,
    
    ```
    cd device/phh/treble
    bash generate.sh lineage
    ```
    
    Also, copy `AndroidProducts.mk` and the files `treble_arm64_bgN.mk`,
    `treble_arm64_bmN.mk`, and `treble_arm64_bvN.mk` to this folder.


    ### Turn on caching to speed up build

    You can speed up subsequent builds by adding these lines to your ~/.bashrc OR ~/.zshrc file:

    ```
    export USE_CCACHE=1
    export CCACHE_COMPRESS=1
    export CCACHE_MAXSIZE=50G # 50 GB
    ``` 

    ## Compilation 

    In ROM folder, for vanilla version:

    ```
    . build/envsetup.sh
    ccache -M 50G -F 0
    lunch treble_arm64_bvN-bp1a-userdebug
    make systemimage -j$(nproc --all)
    ```
    
    For version with google services:

    ```
    . build/envsetup.sh
    ccache -M 50G -F 0
    lunch treble_arm64_bgN-bp1a-userdebug
    make systemimage -j$(nproc --all)
    ```

    For the staged microG version, sync the `microg` manifest group and remove
    proprietary `vendor/gapps` plus the standalone F-Droid privileged extension
    from that build graph. The local-only helper script does this and does not
    publish releases, edit OTA metadata, commit, or push:

    ```
    bash buildmicrog.sh
    ```

    The script writes Android source/build state and ccache to
    `../.android-build`, and writes the image plus `.tar.gz` archive to
    `../images` by default. Override with `MP01_WORKSPACE_BUILD_DIR`,
    `MP01_BUILD_ROOT`, `MP01_CCACHE_DIR`, or `MP01_IMAGE_DIR` if needed.

    Manual microG lunch target:

    ```
    . build/envsetup.sh
    ccache -M 50G -F 0
    bash vendor/partner_gms/vendorsetup.sh
    lunch treble_arm64_bmN-bp1a-userdebug
    make systemimage -j$(nproc --all)
    ```


    ## Compress

    After compilation,
    If you want to compress the build, i recommend use [7-zip](https://aur.archlinux.org/packages/7-zip), for a fast and safe way
    In rom folder,

    ```
    cd out/target/product/tdgsi_arm64_ab
    7zz a system.img.xz "system.img"
    ```
</details>

## Troubleshoot
If you face any conflicts while applying patches, apply the patch manually

## Credits
- [Vasu Bhatia - vbbot](https://github.com/vbbot) - Created [minimal-phone-patching-service](https://github.com/vbbot/minimal-phone-patching-service)
- [LineageOS Team](https://github.com/LineageOS)
- [Phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [Ponces](https://github.com/ponces)
- [Peter Cai](https://github.com/PeterCxy)
- [Iceows](https://github.com/Iceows)
- [ChonDoit](https://github.com/ChonDoit)
- [Nazim N ](https://github.com/naz664)
- [Ahnet](https://github.com/ahnet-69)
- [mytja](https://github.com/mytja)
