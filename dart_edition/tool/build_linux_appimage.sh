#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
flutter_bin=${FLUTTER_BIN:-flutter}
arch=${ARCH:-x86_64}
build_dir="$project_dir/build/linux/x64/release"
bundle_dir="$build_dir/bundle"
app_dir="$build_dir/MonogatariAssistant.AppDir"
output_file="$build_dir/Monogatari-Assistant-$arch.AppImage"
tool_dir="$project_dir/.dart_tool/appimage-tools"
appimagetool="$tool_dir/appimagetool-$arch.AppImage"
desktop_file="$project_dir/linux/packaging/com.heyairu.monogatari_assistant.desktop"
icon_file="$project_dir/linux/packaging/com.heyairu.monogatari_assistant.png"

cd "$project_dir"
"$flutter_bin" build linux --release

cmake -E remove_directory "$app_dir"
cmake -E make_directory "$app_dir/usr/bin"
cmake -E make_directory "$app_dir/usr/share/applications"
cmake -E make_directory "$app_dir/usr/share/icons/hicolor/512x512/apps"
cmake -E copy_directory "$bundle_dir" "$app_dir/usr/bin"
cmake -E copy "$desktop_file" \
  "$app_dir/usr/share/applications/com.heyairu.monogatari_assistant.desktop"
cmake -E copy "$icon_file" \
  "$app_dir/usr/share/icons/hicolor/512x512/apps/com.heyairu.monogatari_assistant.png"
cmake -E copy "$project_dir/linux/packaging/AppRun" "$app_dir/AppRun"
chmod +x "$app_dir/AppRun"

ln -s "usr/share/applications/com.heyairu.monogatari_assistant.desktop" \
  "$app_dir/com.heyairu.monogatari_assistant.desktop"
ln -s "usr/share/icons/hicolor/512x512/apps/com.heyairu.monogatari_assistant.png" \
  "$app_dir/com.heyairu.monogatari_assistant.png"
ln -s "com.heyairu.monogatari_assistant.png" "$app_dir/.DirIcon"

cmake -E make_directory "$tool_dir"
if [ ! -x "$appimagetool" ]; then
  curl --fail --location --output "$appimagetool" \
    "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-$arch.AppImage"
  chmod +x "$appimagetool"
fi

cmake -E rm -f "$output_file"
ARCH="$arch" "$appimagetool" --appimage-extract-and-run \
  "$app_dir" "$output_file"
chmod +x "$output_file"

printf '%s\n' "$output_file"
