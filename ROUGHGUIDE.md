> This is temporary, to be replaced by a properly written guide
1. Backup all data, here be dragons
2. Enable Dev Settings > USB Debugging/OEM Unlocking on
3. adb reboot bootloader (fastboot) (fastboot devices to see if it's there, sometimes doesn't show fastboot mode)
4. fastboot flashing unlock (press vol+ in 5 seconds) - "Start unlock flow"
5. fastboot reboot fastboot (fastbootd)
6. fastboot flash system <system.img> (we don't require resizing partitions or deleting product)
7. fastboot -w doesn't work? idk - go to recovery and wipe data
8. Reboot and make a sacrifice