# Tom OS Ly and Calamares integration (experimental)

This directory contains Tom OS branding and configuration for **Ly** (TTY login manager) and **Calamares** (graphical installer frontend).

## What the build script currently does

- Adds `ly` to the Omarchy target package list.
- Adds `calamares` to the live ISO package list.
- Stages Ly and Calamares configuration, including the Tom OS purple/cyan artwork, into the local Omarchy settings package build.
- Configures Calamares to invoke a handoff script for the existing Omarchy installer.

## Limitations

**Ly is not automatically enabled yet.** Omarchy uses SDDM and its provisioning can re-enable it. The integration must be tested with the installed-system service setup before making Ly the default; otherwise a user could be left without a login screen.

**Calamares is not yet a fully native installer.** Omarchy deploys a prebuilt Btrfs root image and performs custom encryption, Limine and provisioning operations. The frontend currently delegates these operations to the existing Omarchy installer rather than using Calamares' partitioning modules. The handoff's compatibility with the live environment has not been validated.

The ISO has **not** been built or boot-tested with these changes. Test in a VM, inspect the resulting settings package and verify the Calamares modules before considering physical installation. Never treat a Calamares summary screen as proof that a disk install succeeded.
