# Tom OS Ly and Calamares integration (experimental)

This directory contains Tom OS branding and configuration for **Ly** (TTY login manager) and **Calamares** (graphical installer frontend).

## What the build script currently does

- Adds `ly` to the Omarchy target package list.
- Patches Omarchy's service setup to disable `sddm.service` and enable `ly.service`; Ly is configured to use the `omarchy` Wayland session.
- Adds `calamares` to the live ISO package list and packages an **Install Tom OS** application-menu launcher.
- Stages Ly and Calamares configuration, including the Tom OS purple/cyan artwork, into the local Omarchy settings package build.
- Configures Calamares to invoke a handoff script for the existing Omarchy installer.

## Limitations

**Ly is selected as the intended default, but is untested.** The build script patches the upstream service setup that enables SDDM, replacing it with Ly. The first VM build must confirm the Ly unit exists, the `omarchy` session is discoverable, and first-boot provisioning still works. If any of these checks fail, the installed system could boot without a working graphical login.

**Calamares is not yet a fully native installer.** Omarchy deploys a prebuilt Btrfs root image and performs custom encryption, Limine and provisioning operations. The frontend currently delegates these operations to the existing Omarchy installer rather than using Calamares' partitioning modules. The handoff's compatibility with the live environment has not been validated.

The ISO has **not** been built or boot-tested with these changes. Test in a VM, inspect the resulting settings package and verify the Calamares modules before considering physical installation. Never treat a Calamares summary screen as proof that a disk install succeeded.
