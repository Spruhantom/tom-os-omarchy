#!/usr/bin/env bash
set -Eeuo pipefail

# Tom OS: build a custom Omarchy ISO from an installed Omarchy Linux host.
# This script uses Omarchy's supported local-source ISO build workflow.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/work"
OUTPUT_DIR="$SCRIPT_DIR/output"
ISO_REPO="$WORK_DIR/omarchy-iso"
OMARCHY_SOURCE="$WORK_DIR/omarchy"
PKGS_SOURCE="$WORK_DIR/omarchy-pkgs"
BRANCH="quattro"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[[ "$EUID" -ne 0 ]] || fail 'Run as your normal Omarchy user, not directly as root.'
[[ -r /etc/os-release ]] || fail 'Cannot identify the host operating system.'
# shellcheck disable=SC1091
source /etc/os-release
# Omarchy currently identifies itself as ID=arch in /etc/os-release, so verify
# both the Arch base and an installed Omarchy marker. Allow ID=omarchy too in
# case a future release adopts a distinct os-release ID.
[[ "${ID:-}" == arch || "${ID:-}" == omarchy ]] || fail 'Build this ISO on Omarchy Linux (not Ubuntu, Fedora, or plain Arch Linux).'
if ! command -v omarchy-version >/dev/null 2>&1 && [[ ! -d /usr/share/omarchy ]]; then
  fail 'Omarchy markers were not found. Run this script from an installed Omarchy Linux system.'
fi
[[ "$(uname -m)" == x86_64 ]] || fail 'This project is configured for Omarchy Linux x86_64 hosts and ISO output.'

for cmd in git docker python3 jq sha256sum magick; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing dependency: $cmd. On Omarchy, install dependencies with: sudo pacman -S --needed git docker jq python imagemagick"
done

if ! docker info >/dev/null 2>&1 && ! sudo docker info >/dev/null 2>&1; then
  fail 'Docker is not running or cannot be accessed. Start it with: sudo systemctl enable --now docker'
fi

# Conservative space check: source checkouts, package caches, root image, and ISO.
FREE_KB="$(df -Pk "$SCRIPT_DIR" | awk 'NR==2 {print $4}')"
if [[ -n "$FREE_KB" ]] && (( FREE_KB < 35 * 1024 * 1024 )); then
  fail 'At least 35 GB of free disk space is recommended. Free space and retry.'
fi

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
exec > >(tee -a "$OUTPUT_DIR/build.log") 2>&1

ensure_repo() {
  local path="$1" url="$2" branch="$3"
  if [[ ! -d "$path/.git" ]]; then
    info "Cloning $url ($branch)"
    git clone --depth 1 --branch "$branch" --single-branch "$url" "$path"
  else
    info "Updating $(basename "$path") to upstream $branch"
    git -C "$path" fetch --depth 1 origin "$branch"
    git -C "$path" checkout "$branch"
    git -C "$path" reset --hard "origin/$branch"
  fi
}

ensure_repo "$ISO_REPO" 'https://github.com/omacom/omarchy-iso.git' "$BRANCH"
ensure_repo "$OMARCHY_SOURCE" 'https://github.com/omacom/omarchy.git' "$BRANCH"
# The package repository uses master; the ISO builder packages the locally modified source.
ensure_repo "$PKGS_SOURCE" 'https://github.com/omacom/omarchy-pkgs.git' 'master'

git -C "$ISO_REPO" submodule update --init --recursive

LOGO="$SCRIPT_DIR/assets/toms-technology-support-logo.png"
GENERATED_ASSETS="$WORK_DIR/generated-assets"
BOOT_LOGO="$GENERATED_ASSETS/tom-os-boot-logo.png"
ICON="$GENERATED_ASSETS/tom-os-icon.png"
WALLPAPER="$GENERATED_ASSETS/tom-os-wallpaper.png"
WALLPAPER_SOURCE="$SCRIPT_DIR/assets/tom-os-wallpaper.svg"
[[ -f "$LOGO" ]] || fail "Required asset missing: $LOGO"
[[ -f "$WALLPAPER_SOURCE" ]] || fail "Required asset missing: $WALLPAPER_SOURCE"
mkdir -p "$GENERATED_ASSETS"
info 'Generating Tom OS boot logo, application icon, and wallpaper'
magick "$LOGO" -resize 320x320 "$BOOT_LOGO"
magick "$LOGO" -resize 128x128 "$ICON"
magick "$WALLPAPER_SOURCE" -resize 1280x720 "$GENERATED_ASSETS/tom-os-wallpaper-base.png"
magick "$GENERATED_ASSETS/tom-os-wallpaper-base.png" \( "$LOGO" -resize 300x300 \) -gravity center -composite "$WALLPAPER"

info 'Applying Tom OS branding to the local Omarchy source'
# Clean any previous generated theme files before recreating them.
rm -rf "$OMARCHY_SOURCE/themes/tom-os"
mkdir -p "$OMARCHY_SOURCE/themes/tom-os/backgrounds"
cat > "$OMARCHY_SOURCE/themes/tom-os/colors.toml" <<'COLORS'
mode = "dark"
accent = "#8b7cff"
selection = "#2b2452"
muted = "#514a7e"
background = "#090812"
dark_background = "#07060e"
darker_background = "#04040a"
lighter_background = "#19142f"
foreground = "#f6f3ff"
dark_foreground = "#aaa4c7"
light_foreground = "#e4deff"
bright_foreground = "#ffffff"
red = "#ff668d"
yellow = "#f5ce78"
orange = "#ff9d78"
green = "#9be28f"
cyan = "#59e7f2"
blue = "#7aaaff"
magenta = "#b69aff"
brown = "#9b6f67"
bright_red = "#ff7e9d"
bright_yellow = "#ffdb8a"
bright_green = "#b2f0a7"
bright_cyan = "#7af2fa"
bright_blue = "#96bdff"
bright_magenta = "#c7b1ff"
COLORS
cp "$WALLPAPER" "$OMARCHY_SOURCE/themes/tom-os/backgrounds/0-tom-os.png"
cp "$WALLPAPER" "$OMARCHY_SOURCE/themes/tom-os/preview.png"

# Make Tom OS the initial theme on fresh user provisioning. Omarchy's theme switcher
# can still select any other theme later.
THEME_SCRIPT="$OMARCHY_SOURCE/install/user/theme.sh"
[[ -f "$THEME_SCRIPT" ]] || fail "Expected Omarchy theme setup file not found: $THEME_SCRIPT"
python3 - "$THEME_SCRIPT" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
if '"Tokyo Night"' not in s:
    raise SystemExit('Could not find the expected default-theme lines in install/user/theme.sh; upstream changed, stopping safely.')
p.write_text(s.replace('"Tokyo Night"', '"Tom OS"'))
PY

# Replace the image used by Omarchy's Plymouth boot/unlock theme.
PLYMOUTH_LOGO="$OMARCHY_SOURCE/default/plymouth/logo.png"
[[ -f "$PLYMOUTH_LOGO" ]] || fail "Expected Plymouth logo not found: $PLYMOUTH_LOGO"
cp "$BOOT_LOGO" "$PLYMOUTH_LOGO"

# Replace the desktop/about/screen-saver branding assets in the locally built
# omarchy-settings-dev package. The package recipes install these into the system.
SETTINGS_PKG="$PKGS_SOURCE/pkgbuilds/omarchy-settings-dev"
[[ -d "$SETTINGS_PKG" ]] || fail "Expected package recipe not found: $SETTINGS_PKG"
[[ -f "$SETTINGS_PKG/PKGBUILD" ]] || fail "PKGBUILD missing from $SETTINGS_PKG"
# This PKGBUILD packages branding files from the OMARCHY_SRC checkout root,
# so update those source files, not the package recipe directory.
cp "$ICON" "$OMARCHY_SOURCE/icon.png"
if [[ -f "$OMARCHY_SOURCE/logo.svg" ]]; then
  python3 - "$LOGO" "$OMARCHY_SOURCE/logo.svg" <<'PY'
from pathlib import Path
import base64, sys
raw = base64.b64encode(Path(sys.argv[1]).read_bytes()).decode('ascii')
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="942" height="942" viewBox="0 0 942 942"><image width="942" height="942" href="data:image/png;base64,{raw}"/></svg>
'''
Path(sys.argv[2]).write_text(svg)
PY
fi
cat > "$OMARCHY_SOURCE/logo.txt" <<'TXT'
 _____ ___  __  __   ____  ____
|_   _/ _ \\|  \\/  | / ___||  _ \\
  | || | | | |\\/| || |  _ | |_) |
  | || |_| | |  | || |_| ||  __/
  |_| \\___/|_|  |_| \\____||_|
               POWERED BY OMARCHY
TXT
cat > "$OMARCHY_SOURCE/icon.txt" <<'TXT'
TOM OS
Powered by Omarchy
TXT

# Give the installer ISO Tom OS labels while retaining attribution that it is built on Omarchy.
PROFILE="$ISO_REPO/configs/profiledef.sh"
[[ -f "$PROFILE" ]] || fail "ISO profile file not found: $PROFILE"
python3 - "$PROFILE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
repls = {
    'iso_name="omarchy"': 'iso_name="tom-os"',
    'iso_label="OMARCHY_': 'iso_label="TOM_OS_',
    'iso_publisher="Omarchy <https://omarchy.org>"': 'iso_publisher="Tom OS Project (based on Omarchy) <https://omarchy.org>"',
    'iso_application="Omarchy Installer"': 'iso_application="Tom OS Installer - based on Omarchy"',
}
for old, new in repls.items():
    if old not in s:
        raise SystemExit(f'Could not find expected ISO metadata: {old}; upstream changed, stopping safely.')
    s = s.replace(old, new, 1)
p.write_text(s)
PY

# Add Ly to the installed system package set and Calamares to the live ISO.
# Package recipe changes below install the theme/config files in both environments.
info 'Adding Ly and the Calamares frontend'
for p in ly; do
  grep -qxF "$p" "$OMARCHY_SOURCE/install/omarchy-other.packages" ||
    printf '%s\n' "$p" >> "$OMARCHY_SOURCE/install/omarchy-other.packages"
done

LIVE_BUILDER="$ISO_REPO/builder/build-iso.sh"
[[ -f "$LIVE_BUILDER" ]] || fail "Expected ISO builder not found: $LIVE_BUILDER"
python3 - "$LIVE_BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
needle='live_packages_file="$build_cache_dir/packages.$OMARCHY_ARCH"'
if needle not in s:
    raise SystemExit("Omarchy ISO package list anchor changed; cannot include Calamares safely")
s=s.replace(needle, needle+'\n# Tom OS graphical installer frontend (x86_64 only)\nif [[ "$OMARCHY_ARCH" == "x86_64" ]]; then arch_packages+=(calamares); fi',1)
p.write_text(s)
PY

# Omarchy's settings package is already installed in the live ISO and target.
# Bundle our configuration with that package to avoid brittle post-ISO remastering.
PKGBUILD="$SETTINGS_PKG/PKGBUILD"
python3 - "$PKGBUILD" "$SCRIPT_DIR" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
source=Path(sys.argv[2])
s=p.read_text()
needle='package() {'
if needle not in s:
    raise SystemExit('Upstream settings PKGBUILD changed; package() not found')
block='''package() {
  # Tom OS: stage Ly configuration and Calamares branding/frontend.
  install -Dm644 "${srcdir}/omarchy/tom-os/ly/config.ini" "$pkgdir/etc/ly/config.ini"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/settings.conf" "$pkgdir/etc/calamares/settings.conf"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/branding/tom-os/branding.desc" "$pkgdir/usr/share/calamares/branding/tom-os/branding.desc"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/branding/tom-os/welcome.png" "$pkgdir/usr/share/calamares/branding/tom-os/welcome.png"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/branding/tom-os/logo.png" "$pkgdir/usr/share/calamares/branding/tom-os/logo.png"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/modules/tom-os-installer-handoff.conf" "$pkgdir/etc/calamares/modules/tom-os-installer-handoff.conf"
  install -Dm755 "${srcdir}/omarchy/tom-os/calamares/modules/tom-os-installer-handoff.sh" "$pkgdir/usr/lib/calamares/modules/tom-os-installer-handoff.sh"
'''
# The package recipe copies OMARCHY_SRC into srcdir/omarchy in prepare().
s=s.replace(needle,block,1)
p.write_text(s)
PY
mkdir -p "$OMARCHY_SOURCE/tom-os"
cp -a "$SCRIPT_DIR/installer/." "$OMARCHY_SOURCE/tom-os/"
mkdir -p "$OMARCHY_SOURCE/tom-os/calamares/branding/tom-os"
cp "$WALLPAPER" "$OMARCHY_SOURCE/tom-os/calamares/branding/tom-os/welcome.png"
cp "$ICON" "$OMARCHY_SOURCE/tom-os/calamares/branding/tom-os/logo.png"

# NOTE: Omarchy's packaging scripts may isolate the source checkout, so
# confirm the package contains these files during the first test build.
# Ly activation requires explicitly switching away from Omarchy's SDDM setup.
# This is intentionally deferred until the installed-system integration is
# validated to avoid leaving a fresh installation without a working login.

info 'Building Tom OS from an Omarchy Linux host using the official Omarchy ISO builder'
# --local-source is the upstream-supported path for building the ISO with locally
# modified Omarchy and omarchy-pkgs checkouts. It selects the Omarchy edge/dev channel.
(
  cd "$ISO_REPO"
  ./bin/omarchy-iso-make --local-source "$OMARCHY_SOURCE" "$PKGS_SOURCE" --keep-pkg-cache --no-boot-offer
)

LATEST_ISO="$(find "$ISO_REPO/release" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"
[[ -n "$LATEST_ISO" && -f "$LATEST_ISO" ]] || fail "Builder finished but no ISO was found in $ISO_REPO/release"
FINAL_ISO="$OUTPUT_DIR/tom-os-omarchy-x86_64.iso"
cp --reflink=auto "$LATEST_ISO" "$FINAL_ISO"

info 'Build finished'
printf 'ISO: %s\n' "$FINAL_ISO"
printf 'SHA-256: '
sha256sum "$FINAL_ISO"
printf '\nNOTE: This is a custom development-style build using Omarchy local-source support. Test in a VM first.\n'
