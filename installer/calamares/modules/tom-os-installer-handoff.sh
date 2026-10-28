#!/usr/bin/env bash
set -Eeuo pipefail

# Calamares runs this script as its root installer process. Hand off to the
# upstream Omarchy installer because its Btrfs image deployment and boot setup
# are not interchangeable with Calamares' generic unpackfs/bootloader modules.
installer="/usr/bin/omarchy-iso-installer"

if [[ ! -x "$installer" ]]; then
  zenity --error --title="Tom OS installer" --text="The Omarchy installer backend was not found. No disk changes were made." 2>/dev/null || true
  exit 1
fi

exec "$installer"
