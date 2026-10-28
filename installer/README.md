# Tom OS login and installer branding

This directory contains the Tom OS Ly configuration and Calamares branding/frontend files.

## Ly

The build script adds the `ly` package, installs `/etc/ly/config.ini`, and enables the Ly TTY service while disabling SDDM. Confirm the exact service unit names against the Ly package on the target Arch snapshot before using on physical hardware.

## Calamares

Calamares is included as a branded frontend, but Omarchy's installer deploys a prebuilt Btrfs root image and configures Limine, encryption, user provisioning, and machine-specific setup. That is not the same installation model as a generic Calamares `unpackfs` configuration.

For that reason, the initial integration uses a transparent handoff to `omarchy-iso-installer` after the Calamares welcome/locale/keyboard/summary pages. Calamares does not itself perform partitioning or claim to install the OS. A true Calamares-native installer requires a separately implemented and VM-tested backend for the Omarchy image, Btrfs, encryption, bootloader and first-boot provisioning; do not enable destructive generic partition modules until that backend exists.

Test in a VM first. This project has not been end-to-end built or boot-tested.
