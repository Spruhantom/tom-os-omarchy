# Tom OS — Omarchy-based Linux project

![Project status: experimental](https://img.shields.io/badge/status-experimental-orange)

Tom OS is a personal customisation project built on top of **Omarchy Linux**. It aims to apply Tom OS / Toms Technology Support branding, a purple-and-cyan desktop theme, custom wallpaper, and a branded Plymouth logo while retaining Omarchy's underlying Arch Linux system and installer ecosystem.

> **Experimental:** The ISO build has not yet been completed and boot-tested end to end. This project is provided for development and testing. Test in a virtual machine before installing on physical hardware.

## What is included

- `build-tom-os-omarchy.sh` — build wrapper around the upstream Omarchy ISO builder.
- `assets/toms-technology-support-logo.png` — TTS logo used to generate boot and app branding.
- `assets/tom-os-wallpaper.svg` — scalable Tom OS neon wallpaper source.
- `installer/ly/` — Ly login configuration (not yet enabled by default).
- `installer/calamares/` — experimental Tom OS-branded Calamares frontend and Omarchy installer handoff.

**Installer status:** The build script now stages Ly and Calamares packages/configuration, but Ly service activation and a fully native Calamares installation backend remain unimplemented. These changes have not been boot-tested. See [installer/README.md](installer/README.md).

The build script uses ImageMagick to generate the boot logo, app icon, and wallpaper from the included logo and SVG. Generated images and build output are created in the local `work/` and `output/` directories and are not committed to this repository.


The builder is intended to run on an **installed Omarchy Linux x86_64 host**, not Ubuntu, Fedora, or a generic Arch installation. It uses the upstream Omarchy ISO builder's `--local-source` workflow, which builds using the development/edge package channel.

## Requirements

- Installed Omarchy Linux on x86_64
- Docker Engine running
- Git, Docker, jq, Python, ImageMagick, and sudo
- Internet connection
- At least 35 GB free disk space recommended (more is useful)

Install prerequisites:

```bash
sudo pacman -Syu
sudo pacman -S --needed git docker jq python imagemagick
sudo systemctl enable --now docker
```

Do not run the project script directly as root. Review scripts and upstream source before executing them; building uses elevated privileges through Docker and selected host operations.

## Build

1. Download or clone this repository.
2. Open a terminal in the project directory.
3. Make the script executable and syntax-check it:

   ```bash
   chmod +x build-tom-os-omarchy.sh
   bash -n build-tom-os-omarchy.sh
   ```

4. Start the build:

   ```bash
   ./build-tom-os-omarchy.sh
   ```

5. The expected ISO output is:

   ```text
   output/tom-os-omarchy-x86_64.iso
   ```

The script downloads/clones upstream sources, adjusts their local working copies for Tom OS branding, and runs the official ISO builder. A full build can take significant time and disk space. The build log is saved to `output/build.log`.

## Test carefully

Test the ISO in GNOME Boxes, QEMU, or another virtual machine before installing it on physical hardware. A full-disk installation can erase the selected drive; back up important data and confirm the selected target before proceeding.

The live ISO boot splash may differ from the installed-system Plymouth screen. Confirm all branding and session behaviour in a VM. A shell syntax check does not prove that the ISO builds or boots.

## Upstream projects

- [Omarchy ISO builder](https://github.com/omacom/omarchy-iso)
- [Omarchy desktop source](https://github.com/omacom/omarchy)
- [Omarchy package recipes](https://github.com/omacom/omarchy-pkgs)
- [Omarchy manual](https://omarchy.org/manual/getting-started/)

Tom OS is an independent customisation and is not an official release of Omarchy. Respect the upstream project licences and trademarks.
