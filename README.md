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

## Tom OS visual branding

The build script generates a coordinated neon-purple/cyan brand set from the files in `assets/` and `installer/`: a 1920×1080 desktop wallpaper, application icon, Plymouth boot logo, Omarchy theme preview/background, and Calamares welcome/logo artwork. It also sets the Tom OS theme as the initial theme and packages the Ly and Calamares configuration. The branding is based on the visual concept in the project screenshots; the screenshot collage itself is a reference, not used as a desktop wallpaper. These changes are configuration/build-script changes and have not yet been validated by a completed ISO build.

## Tom OS Neon icon theme

The build script now generates an original scalable SVG icon theme named **Tom OS Neon** with matching dark backgrounds and purple/cyan accents for system actions, folders, terminal, settings, software installer, network/status, and common applications. The theme is packaged at `/usr/share/icons/TomOS-Neon`. Because Omarchy/Hyprland components may set icon preferences independently, automatic selection across every application is not yet verified; select **Tom OS Neon** in your desktop/icon-theme settings where supported.

## Tomphone softphone

The ISO build script checks out [Tomphone](https://github.com/Spruhantom/tomos), stages its Qt 6/QML source, compiles it while building the local `omarchy-settings-dev` package, and installs the `tomphone` executable, desktop launcher, and icon into the image. The package includes Qt 6, Baresip, and libpulse runtime dependencies. After installation, launch **Tomphone** from the application menu and enter your own SIP account details. Tomphone's SIP credentials are stored in the user's local config with owner-only permissions.

This integration is experimental and hasn't been verified by a completed ISO build. It requires the upstream Tomphone source to remain compatible with the Qt toolchain and Baresip package in the selected Omarchy build channel.

## Zram (compressed RAM swap)

The build script now explicitly retains `zram-generator` and ensures Omarchy's zram configuration is present, using zstd compression and high-priority swap. The systemd zram generator creates the zram swap device at boot from that configuration. This is intended to be enabled by default; the resulting installed system still needs a VM boot check to confirm zram0 is active.

## Calamares package availability

Calamares is no longer added to the live ISO package list unconditionally, because some configured Omarchy mirrors do not provide the `calamares` package and pacman then aborts the build. The build now skips it by default so the ISO can continue. If you have configured a compatible repository that provides Calamares, you can opt in with `TOM_OS_INSTALL_CALAMARES=1 ./build-tom-os-omarchy.sh`. The branded launcher/configuration is not a working installer unless the Calamares application is actually installed and its handoff is validated.
