#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_appimage=${1:-"$project_dir/build/linux/x64/release/Monogatari-Assistant-x86_64.AppImage"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
bin_home="$HOME/.local/bin"
application_id=com.heyairu.monogatari_assistant
installed_appimage="$bin_home/Monogatari-Assistant.AppImage"
desktop_dir="$data_home/applications"
desktop_file="$desktop_dir/$application_id.desktop"
icon_dir="$data_home/icons/hicolor/512x512/apps"
icon_file="$icon_dir/$application_id.png"

if [ ! -f "$source_appimage" ]; then
  printf 'AppImage not found: %s\n' "$source_appimage" >&2
  exit 1
fi

case $installed_appimage in
  *'"'*|*'`'*|*'$'*|*'\\'*)
    printf 'Unsupported launcher path: %s\n' "$installed_appimage" >&2
    exit 1
    ;;
esac

install -d "$bin_home" "$desktop_dir" "$icon_dir"
install -m 755 "$source_appimage" "$installed_appimage"
install -m 644 \
  "$project_dir/linux/packaging/$application_id.png" "$icon_file"

temporary_desktop=$(mktemp "${TMPDIR:-/tmp}/monogatari-desktop.XXXXXX")
trap 'rm -f "$temporary_desktop"' EXIT HUP INT TERM
sed \
  -e "s|^Exec=.*|Exec=\"$installed_appimage\" %f|" \
  -e "s|^Icon=.*|Icon=$icon_file|" \
  "$project_dir/linux/packaging/$application_id.desktop" \
  >"$temporary_desktop"
install -m 644 "$temporary_desktop" "$desktop_file"

update-desktop-database "$desktop_dir"
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 --noincremental
fi

printf '%s\n' "$installed_appimage"
printf '%s\n' "$desktop_file"
printf '%s\n' "$icon_file"
