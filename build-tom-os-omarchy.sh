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
TOMPHONE_SOURCE="$WORK_DIR/tomphone"
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
ensure_repo "$TOMPHONE_SOURCE" 'https://github.com/Spruhantom/tomos.git' 'main'

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
# Generate consistent artwork from the Tom OS neon-purple/cyan brand.
magick "$LOGO" -resize 320x320 -background '#08071a' -gravity center -extent 512x512 "$BOOT_LOGO"
magick "$LOGO" -resize 128x128 -background '#100b32' -gravity center -extent 256x256 -bordercolor '#8b35ff' -border 5 "$ICON"
magick "$WALLPAPER_SOURCE" -resize 1920x1080 "$GENERATED_ASSETS/tom-os-wallpaper-base.png"
magick "$GENERATED_ASSETS/tom-os-wallpaper-base.png" \( "$LOGO" -resize 420x420 \) -gravity center -composite "$WALLPAPER"
# Reuse the same generated artwork for Omarchy's desktop theme and Calamares welcome screen.
magick "$WALLPAPER" -resize 1600x900 "$GENERATED_ASSETS/tom-os-installer-welcome.png"

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

# Optional compact mode trades live-ISO boot speed for a smaller download.
# Omarchy's default uses zstd level 19 for fast page-fault decompression. XZ
# generally compresses more tightly, but may boot/decompress slower.
PROFILE="$ISO_REPO/configs/profiledef.sh"
if [[ "${TOM_OS_COMPACT_ISO:-1}" == "1" ]]; then
  info 'Enabling compact ISO compression (XZ level 9; slower live boot possible)'
  python3 - "$PROFILE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = """airootfs_image_tool_options=(
  '-comp' 'zstd'
  '-Xcompression-level' '19'
  '-b' '1M'
  '-action' 'uncompressed@subpathname(var/cache/omarchy/mirror/offline)'
)"""
new = """airootfs_image_tool_options=(
  '-comp' 'xz'
  '-Xdict-size' '100%'
  '-b' '1M'
  '-action' 'uncompressed@subpathname(var/cache/omarchy/mirror/offline)'
)"""
if old not in s:
    raise SystemExit('Could not locate expected SquashFS compression settings; upstream changed, stopping safely.')
p.write_text(s.replace(old, new, 1))
PY
fi

# Give the installer ISO Tom OS labels while retaining attribution that it is built on Omarchy.
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

# Ensure compressed RAM swap (zram) is present in every Tom OS build.
# Omarchy provides the config, while zram-generator creates the zram device
# automatically at boot when it sees /usr/lib/systemd/zram-generator.conf.d.
OTHER_PACKAGES="$OMARCHY_SOURCE/install/omarchy-other.packages"
grep -qxF 'zram-generator' "$OTHER_PACKAGES" || printf '%s\n' 'zram-generator' >> "$OTHER_PACKAGES"
ZRAM_CONFIG="$OMARCHY_SOURCE/default/systemd/zram-generator.conf.d/90-omarchy.conf"
if [[ ! -f "$ZRAM_CONFIG" ]]; then
  mkdir -p "$(dirname "$ZRAM_CONFIG")"
  cat > "$ZRAM_CONFIG" <<'ZRAM'
# Tom OS compressed RAM swap. zram-generator creates zram0 during boot.
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
ZRAM
fi

# Make Ly the default login manager in the installed system. Omarchy explicitly
# enables SDDM in install/config/enable-services.sh; patch that exact upstream
# line and fail closed if upstream has changed, rather than merely installing Ly.
ENABLE_SERVICES="$OMARCHY_SOURCE/install/config/enable-services.sh"
[[ -f "$ENABLE_SERVICES" ]] || fail "Expected service setup script not found: $ENABLE_SERVICES"
python3 - "$ENABLE_SERVICES" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='systemctl enable sddm.service'
new='systemctl disable sddm.service || true\nsystemctl enable ly.service'
if new in s:
    raise SystemExit(0)
if s.count(old) != 1:
    raise SystemExit('Could not safely locate the single SDDM enable line; upstream changed, stopping safely.')
p.write_text(s.replace(old, new, 1))
PY

# Compact profile: remove selected large optional desktop/apps and hardware-specific
# extras from the target image. Core Hyprland/Omarchy shell, networking, audio,
# fonts, and installer remain. This is opt-in by default for Tom OS builds.
if [[ "${TOM_OS_COMPACT_PACKAGES:-1}" == "1" ]]; then
  info 'Removing optional large applications for the compact Tom OS profile'
  python3 - "$OMARCHY_SOURCE/install/omarchy-base.packages" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
if not p.exists():
    raise SystemExit(f"Expected package list not found: {p}")
remove = {
    "chromium", "docker", "docker-buildx", "docker-compose", "dotnet-runtime",
    "libreoffice-fresh", "mariadb-libs", "moonlight-qt", "obsidian", "pinta",
    "qemu-user-static-binfmt", "ruby", "superwhisper-bin", "tesseract",
    "tesseract-data-eng", "gpu-screen-recorder", "yt-dlp", "lsp-plugins-lv2",
    "vpl-gpu-rt", "intel-ipu7-camera", "intel-lpmd", "macbook12-spi-driver-dkms",
    "nvidia-580xx-dkms", "nvidia-580xx-utils", "lib32-nvidia-580xx-utils",
    "tuxedo-drivers-nocompatcheck-dkms", "asusctl", "asus-proart-p14-speaker-firmware",
    "surface-pro-11-sensors", "surface-pro-11-support", "dell-xps-touchpad-haptics",
    "dell-xps13-sidecar-amps", "linux-firmware-cirrus-dx13260",
    "apple-t2-audio-config", "t2fanrd", "qmk-hid",
}
lines=p.read_text().splitlines()
p.write_text("\n".join(line for line in lines if line.strip() not in remove) + "\n")
PY
  # Also drop selected optional multimedia/dev utilities from the supplemental list.
  python3 - "$OMARCHY_SOURCE/install/omarchy-other.packages" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
remove={"broadcom-wl-dkms","dkms","intel-media-driver","libva-intel-driver",
        "libva-nvidia-driver","nvidia-dkms","nvidia-open-dkms","nvidia-utils",
        "lib32-nvidia-utils","pipewire-libcamera","sof-firmware","thermald",
        "libvpl","vulkan-asahi","iptsd","linux-firmware-marvell",
        "apple-bcm-firmware-fetcher","linux-t2","linux-t2-headers"}
lines=p.read_text().splitlines()
p.write_text("\n".join(line for line in lines if line.strip() not in remove) + "\n")
PY
fi

LIVE_BUILDER="$ISO_REPO/builder/build-iso.sh"
[[ -f "$LIVE_BUILDER" ]] || fail "Expected ISO builder not found: $LIVE_BUILDER"
python3 - "$LIVE_BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
needle='live_packages_file="$build_cache_dir/packages.$OMARCHY_ARCH"'
if needle not in s:
    raise SystemExit("Omarchy ISO package list anchor changed; cannot configure optional Calamares safely")
addition='''\n# Calamares is optional because it is not present in every Omarchy package mirror.
# Enable only when the configured package source provides it: TOM_OS_INSTALL_CALAMARES=1.
if [[ "${TOM_OS_INSTALL_CALAMARES:-0}" == "1" && "$OMARCHY_ARCH" == "x86_64" ]]; then
  arch_packages+=(calamares)
fi'''
s=s.replace(needle, needle+addition, 1)
p.write_text(s)
PY

# Generate a scalable neon purple/cyan icon theme for Tom OS.
ICON_THEME="$OMARCHY_SOURCE/tom-os/icons/TomOS-Neon"
mkdir -p "$ICON_THEME/scalable/apps" "$ICON_THEME/scalable/places" "$ICON_THEME/scalable/actions"
python3 - "$ICON_THEME" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
icons={
 "tom-os":("TTS","#b44cff","#23eaff"),"folder":("▱","#b44cff","#23eaff"),
 "folder-home":("⌂","#b44cff","#23eaff"),"folder-documents":("▤","#b44cff","#23eaff"),
 "folder-download":("↓","#b44cff","#23eaff"),"folder-music":("♫","#b44cff","#23eaff"),
 "folder-pictures":("▧","#b44cff","#23eaff"),"folder-videos":("▶","#b44cff","#23eaff"),
 "utilities-terminal":(">_","#23eaff","#b44cff"),"preferences-system":("⚙","#23eaff","#b44cff"),
 "system-software-install":("✚","#23eaff","#b44cff"),"system-help":("?","#23eaff","#b44cff"),
 "system-reboot":("↻","#23eaff","#b44cff"),"system-shutdown":("⏻","#23eaff","#b44cff"),
 "network-wireless":("◔","#23eaff","#b44cff"),"network-bluetooth":("ᛒ","#23eaff","#b44cff"),
 "battery":("▰","#23eaff","#b44cff"),"audio-volume-high":("◖","#23eaff","#b44cff"),
 "weather-clear-night":("☾","#b44cff","#23eaff"),"firefox":("F","#ff42d0","#23eaff"),
 "chromium":("◉","#23eaff","#b44cff"),"steam":("S","#23eaff","#b44cff"),
 "discord":("◕","#b44cff","#23eaff"),"spotify":("≋","#23eaff","#b44cff"),
 "code":("</>","#23eaff","#b44cff"),"obsidian":("◇","#b44cff","#23eaff"),
 "gimp":("G","#b44cff","#23eaff"),"calamares":("↓","#23eaff","#b44cff"),
 "system-file-manager":("▱","#b44cff","#23eaff"),"computer":("▱","#23eaff","#b44cff"),
}
for name,(glyph,c1,c2) in icons.items():
    if name=="tom-os":
        art='<circle cx="48" cy="48" r="39" fill="#100a32" stroke="%s" stroke-width="3"/><circle cx="48" cy="48" r="32" fill="none" stroke="%s" stroke-width="2"/><text x="48" y="56" font-size="21" font-style="italic" font-family="serif" text-anchor="middle" fill="#fff">TTS</text>'%(c1,c2)
    elif name.startswith("folder"):
        art='<path d="M12 27 Q12 22 18 22 H39 L46 30 H78 Q84 30 84 36 V73 Q84 79 78 79 H18 Q12 79 12 73Z" fill="#171044" stroke="%s" stroke-width="3"/><text x="48" y="64" font-size="30" font-family="DejaVu Sans" text-anchor="middle" fill="%s">%s</text>'%(c1,c2,glyph)
    else:
        size="20" if len(glyph)>3 else "36"
        art='<rect x="8" y="8" width="80" height="80" rx="19" fill="#09091b" stroke="%s" stroke-width="3"/><rect x="14" y="14" width="68" height="68" rx="14" fill="none" stroke="%s" stroke-opacity=".65"/><text x="48" y="59" font-size="%s" font-family="DejaVu Sans" font-weight="bold" text-anchor="middle" fill="%s">%s</text>'%(c1,c2,size,c2,glyph)
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" rx="22" fill="#050612"/><circle cx="48" cy="48" r="43" fill="%s" opacity=".12"/>%s</svg>'%(c1,art)
    cat="places" if name.startswith("folder") else "actions" if name.startswith("system-") else "apps"
    (root/"scalable"/cat/(name+".svg")).write_text(svg)
(root/"index.theme").write_text("[Icon Theme]\nName=Tom OS Neon\nComment=Neon purple and cyan icons\nInherits=hicolor\nDirectories=scalable/apps,scalable/places,scalable/actions\n\n[scalable/apps]\nSize=96\nType=Scalable\nMinSize=16\nMaxSize=512\nContext=Applications\n\n[scalable/places]\nSize=96\nType=Scalable\nMinSize=16\nMaxSize=512\nContext=Places\n\n[scalable/actions]\nSize=96\nType=Scalable\nMinSize=16\nMaxSize=512\nContext=Actions\n")
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
needle='  cd "$srcdir/omarchy"'
if needle not in s:
    raise SystemExit('Upstream settings PKGBUILD changed; expected cd into source checkout not found')
block='''  # Tom OS branding files are staged in the local Omarchy source checkout.
  install -Dm644 "${srcdir}/omarchy/tom-os/ly/config.ini" "$pkgdir/etc/ly/config.ini"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/settings.conf" "$pkgdir/etc/calamares/settings.conf"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/branding/tom-os/branding.desc" "$pkgdir/usr/share/calamares/branding/tom-os/branding.desc"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/branding/tom-os/welcome.png" "$pkgdir/usr/share/calamares/branding/tom-os/welcome.png"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/branding/tom-os/logo.png" "$pkgdir/usr/share/calamares/branding/tom-os/logo.png"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/modules/tom-os-installer-handoff.conf" "$pkgdir/etc/calamares/modules/shellprocess.conf"
  install -Dm755 "${srcdir}/omarchy/tom-os/calamares/modules/tom-os-installer-handoff.sh" "$pkgdir/usr/lib/calamares/modules/tom-os-installer-handoff.sh"
  install -Dm644 "${srcdir}/omarchy/tom-os/calamares/tom-os-installer.desktop" "$pkgdir/usr/share/applications/tom-os-installer.desktop"
  install -d "$pkgdir/usr/share/icons/TomOS-Neon"
  cp -a "${srcdir}/omarchy/tom-os/icons/TomOS-Neon/." "$pkgdir/usr/share/icons/TomOS-Neon/"
'''
if block.strip() not in s:
    s=s.replace(needle, needle+'\n'+block, 1)
p.write_text(s)
PY
# Extend the Omarchy settings package to build and install Tomphone.
python3 - "$PKGBUILD" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text()
def add_to_array(text, name, additions):
    pattern=rf"(?ms)^{name}=\(\n(.*?)^\)"
    m=re.search(pattern,text)
    if not m: raise SystemExit(f"Could not find {name} array in settings PKGBUILD")
    body=m.group(1)
    for item in additions:
        if not re.search(rf"(?m)^\s*'{re.escape(item)}'\s*$",body):
            body += f"  '{item}'\n"
    return text[:m.start(1)]+body+text[m.end(1):]
s=add_to_array(s,"depends",["qt6-base","qt6-declarative","baresip","libpulse"])
s=add_to_array(s,"makedepends",["qt6-base","qt6-declarative","qt6-tools","make"])
build_block='''build() {
  cd "$srcdir/omarchy/tom-os/tomphone-app"
  qmake6 tomphone.pro
  make -j1
}

'''
if 'cd "$srcdir/omarchy/tom-os/tomphone-app"' not in s:
    marker="package() {"
    if s.count(marker)!=1: raise SystemExit("Could not locate package() in settings PKGBUILD")
    s=s.replace(marker,build_block+marker,1)
pkg_marker='  # Tom OS branding files are staged in the local Omarchy source checkout.'
tomphone_install='''  # Tomphone SIP softphone.
  install -Dm755 "\${srcdir}/omarchy/tom-os/tomphone-app/tomphone" "$pkgdir/usr/bin/tomphone"
  install -Dm644 "\${srcdir}/omarchy/tom-os/tomphone-app/tomphone.desktop" "$pkgdir/usr/share/applications/tomphone.desktop"
  install -Dm644 "\${srcdir}/omarchy/tom-os/tomphone-app/tomphone.svg" "$pkgdir/usr/share/icons/hicolor/scalable/apps/tomphone.svg"
'''
if tomphone_install.strip() not in s:
    if pkg_marker not in s: raise SystemExit("Tom OS branding insertion point missing from settings package()")
    s=s.replace(pkg_marker,tomphone_install+pkg_marker,1)
p.write_text(s)
PY
mkdir -p "$OMARCHY_SOURCE/tom-os"
cp -a "$SCRIPT_DIR/installer/." "$OMARCHY_SOURCE/tom-os/"
mkdir -p "$OMARCHY_SOURCE/tom-os/calamares/branding/tom-os"
cp "$WALLPAPER" "$OMARCHY_SOURCE/tom-os/calamares/branding/tom-os/welcome.png"
cp "$ICON" "$OMARCHY_SOURCE/tom-os/calamares/branding/tom-os/logo.png"
# Stage Tomphone source and launcher assets into the custom package source.
mkdir -p "$OMARCHY_SOURCE/tom-os/tomphone-app"
cp -a "$TOMPHONE_SOURCE/src" "$TOMPHONE_SOURCE/tomphone.pro" "$OMARCHY_SOURCE/tom-os/tomphone-app/"
cp "$TOMPHONE_SOURCE/pkgbuild/tomphone.desktop" "$TOMPHONE_SOURCE/pkgbuild/tomphone.svg" "$OMARCHY_SOURCE/tom-os/tomphone-app/"

# The service setup above selects Ly instead of SDDM. This remains an
# experimental change until a VM build confirms the Ly session reaches Omarchy's
# Hyprland desktop and first-boot provisioning completes correctly.

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
