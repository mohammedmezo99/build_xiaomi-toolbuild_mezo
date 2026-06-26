#!/bin/bash
set -e

work_dir=$(pwd)
source "$work_dir/functions.sh"

MAIN_FOLDER="$work_dir/build/baserom/images"
rom_os=$(cat "$work_dir/bin/ddevice/rom_os.txt")
device_code=$(cat "$work_dir/bin/ddevice/device_f.txt")

LAUNCHER_DIR="$work_dir/bin/modfile/OS3/launcher"

MIUI_HOME_SRC="$LAUNCHER_DIR/MiuiHome"
XIAOMI_EU_EXT_SRC="$LAUNCHER_DIR/XiaomiEUExt"
PERMISSIONS_SRC="$LAUNCHER_DIR/permissions"

PRODUCT="$MAIN_FOLDER/product"
SYSTEM_EXT="$MAIN_FOLDER/system_ext"
VENDOR="$MAIN_FOLDER/vendor"

INIT_RC="$SYSTEM_EXT/etc/init/init.miui.ext.rc"
PRODUCT_PERMISSIONS="$PRODUCT/etc/permissions"
VENDOR_PROP="$VENDOR/build.prop"

MOD_NAME="OS3 Launcher"

find_apk_by_package() {
  local search_dir="$1"
  local wanted_pkg="$2"

  [ -d "$search_dir" ] || return 1

  while IFS= read -r apk; do
    pkg="$(aapt dump badging "$apk" 2>/dev/null | sed -n "s/package: name='\([^']*\)'.*/\1/p" | head -n1)"
    if [ "$pkg" = "$wanted_pkg" ]; then
      printf '%s\n' "$apk"
      return 0
    fi
  done < <(find "$search_dir" -type f -iname "*.apk" 2>/dev/null)

  return 1
}

detect_poco_device() {
  if grep -RIsi "poco" "$work_dir/bin/ddevice" 2>/dev/null | grep -qi "poco"; then
    return 0
  fi

  if grep -RIsi "POCO" \
    "$MAIN_FOLDER/vendor" \
    "$MAIN_FOLDER/odm" \
    "$MAIN_FOLDER/product" \
    "$MAIN_FOLDER/system_ext" 2>/dev/null | grep -qi "POCO"; then
    return 0
  fi

  if find_apk_by_package "$PRODUCT" "com.mi.android.globallauncher" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

copy_launcher_files() {
  mkdir -p "$PRODUCT/priv-app"
  mkdir -p "$PRODUCT_PERMISSIONS"

  if [ -d "$MIUI_HOME_SRC" ] && [ -f "$MIUI_HOME_SRC/MiuiHome.apk" ]; then
    rm -rf "$PRODUCT/priv-app/MiuiHome"
    cp -a "$MIUI_HOME_SRC" "$PRODUCT/priv-app/MiuiHome"
    mods "[$MOD_NAME] MiuiHome copied"
  else
    warn "[$MOD_NAME] MiuiHome source missing"
    return 1
  fi

  if [ -d "$XIAOMI_EU_EXT_SRC" ] && [ -f "$XIAOMI_EU_EXT_SRC/XiaomiEUExt.apk" ]; then
    rm -rf "$PRODUCT/priv-app/XiaomiEUExt"
    cp -a "$XIAOMI_EU_EXT_SRC" "$PRODUCT/priv-app/XiaomiEUExt"
    mods "[$MOD_NAME] XiaomiEUExt copied"
  else
    warn "[$MOD_NAME] XiaomiEUExt source missing, skipped"
  fi

  if [ -d "$PERMISSIONS_SRC" ]; then
    cp -a "$PERMISSIONS_SRC"/. "$PRODUCT_PERMISSIONS"/
    mods "[$MOD_NAME] permissions copied"
  else
    warn "[$MOD_NAME] permissions folder missing"
  fi
}

remove_origin_launchers() {
  isOriginHome=$(find "$MAIN_FOLDER" -type d \( \
    -name "MiuiHomeT" \
    -o -name "MiuiHome" \
    -o -name "MiLauncherGlobal" \
    -o -name "PocoHome" \
    -o -name "PocoLauncher" \
    -o -name "GlobalLauncher" \
  \) 2>/dev/null)

  if [ -n "$isOriginHome" ]; then
    rm -rf $isOriginHome
    mods "[$MOD_NAME] old launcher folders removed"
  fi
}

remove_poco_launcher_by_package() {
  removed=0

  for scan_dir in "$PRODUCT/priv-app" "$PRODUCT/app" "$PRODUCT/data-app"; do
    [ -d "$scan_dir" ] || continue

    while IFS= read -r apk; do
      pkg="$(aapt dump badging "$apk" 2>/dev/null | sed -n "s/package: name='\([^']*\)'.*/\1/p" | head -n1)"

      if [ "$pkg" = "com.mi.android.globallauncher" ]; then
        app_dir="$(dirname "$apk")"
        rm -rf "$app_dir"
        removed=$((removed + 1))
        mods "[$MOD_NAME] removed POCO launcher: $app_dir"
      fi
    done < <(find "$scan_dir" -type f -iname "*.apk" 2>/dev/null)
  done

  if [ "$removed" -eq 0 ]; then
    warn "[$MOD_NAME] no POCO launcher APK removed by package name"
  fi
}

patch_poco_init() {
  if [ -f "$INIT_RC" ]; then
    if grep -q "com.mi.android.globallauncher" "$INIT_RC"; then
      sed -i "s/com.mi.android.globallauncher/com.miui.home/g" "$INIT_RC"
      mods "[$MOD_NAME] POCO init patched to com.miui.home"
    else
      mods "[$MOD_NAME] init already clean"
    fi
  else
    warn "[$MOD_NAME] init.miui.ext.rc not found"
  fi
}

clean_vendor_privapp_enforce() {
  if [ -f "$VENDOR_PROP" ]; then
    sed -i "/^ro.control_privapp_permissions=enforce$/d" "$VENDOR_PROP"
    mods "[$MOD_NAME] vendor privapp enforcement cleaned"
  else
    warn "[$MOD_NAME] vendor/build.prop not found"
  fi
}

if [[ "$rom_os" != "OS3" ]]; then
  warn "[$MOD_NAME] skipped: ROM is not OS3"
  exit 0
fi

if grep -qw "$device_code" "$work_dir/bin/ddevice/data/pad_data.txt"; then
  mods "Pad Device!! Skipping Adding Launcher"
  exit 0
fi

if detect_poco_device; then
  mods "[$MOD_NAME] POCO device detected, applying MIUI Launcher for POCO"

  remove_poco_launcher_by_package
  remove_origin_launchers
  patch_poco_init
  copy_launcher_files
  clean_vendor_privapp_enforce

  mods "Modify Home Done"
  exit 0
fi

mods "[$MOD_NAME] Non-POCO device detected, applying normal OS3 launcher"

remove_origin_launchers
copy_launcher_files

mods "Modify Home Done"