# Tom OS — Omarchy-based Linux

Tom OS is an experimental, custom-branded build based on Omarchy Linux/Arch Linux.

## Build on Omarchy Linux

Install the required host tools:

```bash
sudo pacman -S --needed git docker jq python imagemagick
sudo systemctl enable --now docker
```

Clone and build:

```bash
git clone https://github.com/Spruhantom/tom-os-omarchy.git
cd tom-os-omarchy
chmod +x build-tom-os-omarchy.sh
bash -n build-tom-os-omarchy.sh
./build-tom-os-omarchy.sh
```

The expected output is `output/tom-os-omarchy-x86_64.iso`. The build needs substantial disk space (at least 35 GB recommended) for source checkouts, package caches, the root image and final ISO.

## Compact build profile

The build script now enables two size-oriented options by default:

- `TOM_OS_COMPACT_PACKAGES=1` removes a selected set of large optional applications and some hardware-specific packages from the installed system.
- `TOM_OS_COMPACT_ISO=1` uses XZ compression for the live SquashFS instead of Omarchy's default Zstandard compression. This can make the ISO smaller, but may make live boot and application loading slower.

To retain the broader package set, set `TOM_OS_COMPACT_PACKAGES=0`. To restore the faster default Zstandard compression, set `TOM_OS_COMPACT_ISO=0`.

Example:

```bash
TOM_OS_COMPACT_PACKAGES=1 TOM_OS_COMPACT_ISO=1 ./build-tom-os-omarchy.sh
```

**A 3 GB ISO is a target, not a guarantee.** The project has not yet produced a measured build with these settings. Omarchy ships a complete desktop root image and offline package mirror, so getting below 3 GB may require more extensive changes to its installer/image architecture. The compact package profile also reduces optional features and some device-specific support; check the package removal list in `build-tom-os-omarchy.sh` before installing on hardware.

## Ly and Calamares status

The build script now patches Omarchy's service setup to disable SDDM and enable Ly, and configures Ly to start the Omarchy Wayland session. Calamares is included as an experimental graphical frontend that hands off to Omarchy's own installer; it is **not** a native Calamares partitioning/install backend. These changes have not yet been built or tested in a VM, so a working login or installation is not guaranteed. See [installer/README.md](installer/README.md).

## Testing status

This is experimental. The ISO has not been built and boot-tested end-to-end. Test in a virtual machine before writing it to USB or installing it on physical hardware. Keep backups and do not assume a themed installer has successfully installed until the installed system boots.
