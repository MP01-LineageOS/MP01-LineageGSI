### LineageOS 22.2 GSI for Minimal Phone (MP01)
You'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [TrebleDroid Wiki](https://github.com/TrebleDroid/treble_experimentations/wiki).

### To-Do
- [ ] Refresh Panel (Refresh Button)
- [ ] Integrate e-Ink Panel (With double press of refresh button)
- [ ] Port Minimal Boot/Shutdown Animation (Screen is properly turned off when shutting down)
- [ ] Make default wallpaper(s) white
  - [ ] Include Styled B/W Wallpapers?
- [ ] White QS (Fix major ghosting in QS)
- [ ] Build Signing
- [ ] Make build script more fault tolerant
- [ ] CI/CD for building

### Build Script (Testing)
```bash
bash <(curl -s https://raw.githubusercontent.com/chardidathing/MP01-LineageGSI/refs/heads/15/build.sh)
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
    
        git clone https://github.com/MisterZtr/treble_manifest.git .repo/local_manifests  -b 15-los-qpr2
    


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
    
    Also, copy the files treble_arm64_bgN.mk and treble_arm64_bvN.mk to this folder


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
