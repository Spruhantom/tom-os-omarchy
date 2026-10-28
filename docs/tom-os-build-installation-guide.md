# Tom OS Build & Installation Guide

**Review-approved version — 28 October 2026**

Tom OS is an experimental, custom-branded build based on Omarchy Linux/Arch Linux. This guide covers building the ISO on an installed Omarchy system and testing it safely.

> **Important:** The project has not been built and boot-tested end-to-end. A 3 GB ISO is a target, not a measured result. Test in a virtual machine first; do not install an untested build on your main computer.

## 1. Requirements

- An installed Omarchy Linux system on x86_64. The build script is not intended for Ubuntu, Fedora, plain Arch Linux, or a restricted container.
- At least 35 GB free disk space (more is recommended).
- Stable internet access.
- Docker, Git, jq, Python and ImageMagick.
- GNOME Boxes or another virtual machine application for testing.

Back up important files. Do not use a physical disk for first-run installer testing.

## 2. Install build dependencies

Open a terminal on Omarchy Linux and run:

```bash
sudo pacman -S --needed git docker jq python imagemagick
sudo systemctl enable --now docker
```

Do not run the whole build script as root; it deliberately refuses to run that way.

## 3. Get the project

For a fresh checkout:

```bash
git clone https://github.com/Spruhantom/tom-os-omarchy.git
cd tom-os-omarchy
```

If you already cloned the repository, update it:

```bash
cd tom-os-omarchy
git pull
```

## 4. Check the build script

```bash
chmod +x build-tom-os-omarchy.sh
bash -n build-tom-os-omarchy.sh
```

If the syntax check reports an error, stop and resolve it before building. A clean syntax check confirms shell syntax only; it does not prove the upstream integration works.

## 5. Build the compact ISO

The build script enables the compact package profile and XZ SquashFS compression by default. This may reduce the ISO size but can make live boot and application loading slower. The 3 GB target is not guaranteed.

```bash
./build-tom-os-omarchy.sh
```

Expected output:

```text
output/tom-os-omarchy-x86_64.iso
```

Check the file size and checksum:

```bash
ls -lh output/tom-os-omarchy-x86_64.iso
sha256sum output/tom-os-omarchy-x86_64.iso
```

The build log is at `output/build.log`.

### If the build fails

- Read the final 30–50 lines of the terminal output or `output/build.log`.
- Check free space with `df -h`.
- Check Docker with `sudo systemctl status docker --no-pager`.
- Keep the `work/` directory until you have captured the error.

## 6. Test in GNOME Boxes

Create a new virtual machine and select the generated ISO. Use a disposable VM and do not attach important host folders or physical disks.

Suggested starting settings (not official minimum requirements):

- 4 CPU cores if available.
- 6–8 GB RAM if available.
- 30–40 GB virtual disk for installer testing.
- UEFI firmware if offered.
- Network enabled if required by the installer.

If the ISO does not boot, stop and troubleshoot before attempting a real installation.

## 7. Installer and login manager status

The project currently uses Omarchy's existing installer flow. Calamares is an experimental branded frontend/handoff, not a complete native Calamares partitioning and deployment backend. Ly configuration is present, but Ly is not yet enabled as the default login manager.

Treat installer screens as experimental and use a disposable VM disk only. Do not select a physical disk. Do not assume installation succeeded until the VM reboots into the installed system.

## 8. Verify the result

In the VM, check:

- The ISO boots without errors.
- Tom OS branding and wallpaper appear.
- The desktop session starts; keyboard and networking work.
- Installation completes without errors.
- The installed VM reboots successfully.
- The login manager works after reboot.

The compact package profile removes selected optional applications and some hardware-specific packages. Review the package removal list in `build-tom-os-omarchy.sh` before considering installation on physical hardware.

## 9. Troubleshooting information

Useful commands:

```bash
df -h
sudo systemctl status docker --no-pager
ls -lh output/
tail -n 50 output/build.log
```

When asking for help, include the command you ran, the full error text, whether the failure happened during build or VM boot, and the ISO size if one was produced.

## Known limitations

- The ISO has not been built and boot-tested end-to-end.
- A 3 GB ISO is a goal, not a measured result.
- Removing packages may reduce support for some hardware and optional apps.
- Ly is not yet enabled as the default display manager.
- Calamares is not yet a standalone installer backend; the current design hands off to Omarchy's installer.

Repository: https://github.com/Spruhantom/tom-os-omarchy
