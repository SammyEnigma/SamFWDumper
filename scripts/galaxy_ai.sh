#!/bin/bash
# =============================================================================
# SamFWDumper - Automated Samsung Firmware Extraction
# Copyright (C) 2026 Xiatsuma
# Licensed under PolyForm Noncommercial License 1.0.0
# https://polyformproject.org/licenses/noncommercial/1.0.0
#
# You may NOT use this file except in compliance with the License.
# Commercial use, removal of this header, or distribution without attribution
# is strictly prohibited. For permissions: https://github.com/Xiatsuma
# =============================================================================
set -e

echo "═══════════════════════════════════════"
echo "   Galaxy AI Feature Extractor"
echo "═══════════════════════════════════════"

URL="$1"
ZIP_TYPE="${2:-MODULES_USAGE}"

shift 2

chmod +x tools/android-tools/* tools/erofs-utils/* 2>/dev/null || true

if [ "$ZIP_TYPE" = "PORT_USAGE" ]; then
  echo "PORT_USAGE is not available yet. Coming soon."
  exit 0
fi

PRIV_FEATURES=""
[ "${1}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES Accessibility"
[ "${2}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES AirCommand"
[ "${3}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES AlKernel"
[ "${4}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES Bixby"
[ "${5}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES BixbyInterpreter"
[ "${6}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES DressRoom"
[ "${7}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES MediaSearch"
[ "${8}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES Moments"
[ "${9}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES OfflineLanguageModel"
[ "${10}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES PhotoEditor"
[ "${11}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES SamsungAiCore"
[ "${12}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES SamsungGallery"
[ "${13}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES SamsungSmartSuggestions"
[ "${14}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES SecSettingsIntelligence"
[ "${15}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES SemanticSearch"
[ "${16}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES ShareLive"
[ "${17}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES SpriteWallpaper"
[ "${18}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES StoryService"
[ "${19}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES VisionModel"
[ "${20}" = "true" ] && PRIV_FEATURES="$PRIV_FEATURES WallpaperMagician"
PRIV_FEATURES="${PRIV_FEATURES# }"

APP_FEATURES=""
[ "${21}" = "true" ] && APP_FEATURES="$APP_FEATURES SketchBook"
[ "${22}" = "true" ] && APP_FEATURES="$APP_FEATURES VideoEditorLite"
[ "${23}" = "true" ] && APP_FEATURES="$APP_FEATURES VisualCloudCore"
APP_FEATURES="${APP_FEATURES# }"

if [ -z "$PRIV_FEATURES" ] && [ -z "$APP_FEATURES" ]; then
  echo "❌ No features selected!"
  exit 1
fi

echo "Zip type: $ZIP_TYPE"
echo "priv-app: $PRIV_FEATURES"
echo "app: $APP_FEATURES"

echo ""; echo "[1/6] Downloading..."
wget -q --no-check-certificate --content-disposition "$URL"
ZIP_FILE=$(ls -t *.zip 2>/dev/null | head -1)
[ ! -f "$ZIP_FILE" ] && { echo "❌ Download failed"; exit 1; }
FILESIZE=$(stat -c%s "$ZIP_FILE")
[ "$FILESIZE" -eq 0 ] && { echo "❌ Empty file"; exit 1; }
echo "✅ Downloaded: $(numfmt --to=iec $FILESIZE)"

CSC_CODE=$(echo "$ZIP_FILE" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z]{3}$' | grep -v -E '^(COM|SAM|FAC)$' | head -1)
AP_CODE=$(echo "$ZIP_FILE" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z][A-Z0-9]{11,}$' | head -1)
echo "$CSC_CODE" > csc_code.txt
echo "$AP_CODE" > ap_code.txt
echo "Firmware: $AP_CODE | CSC: $CSC_CODE"

echo ""; echo "[2/6] Extracting ZIP..."
unzip -o "$ZIP_FILE" >/dev/null 2>&1
rm -f "$ZIP_FILE"
echo "✅ Done"

echo ""; echo "[3/6] Extracting AP..."
AP_FILE=$(find . -name "AP_*.tar.md5" -o -name "AP_*.tar" | head -n 1)
[ -z "$AP_FILE" ] && { echo "❌ AP file not found"; exit 1; }
tar -xf "$AP_FILE" >/dev/null 2>&1
rm -f "$AP_FILE"
echo "✅ Done"

echo ""; echo "[4/6] Getting system.img and product.img..."
SUPER_FILE=$(find . -maxdepth 1 -name "super.img*" -o -name "super.img" | head -n 1)
if [ -n "$SUPER_FILE" ]; then
  if [[ "$SUPER_FILE" == *.lz4 ]]; then
    lz4 -d "$SUPER_FILE" "super.img" 2>/dev/null
    SUPER_FILE="super.img"
  fi
  if file "$SUPER_FILE" 2>/dev/null | grep -q "sparse"; then
    simg2img "$SUPER_FILE" "super.raw.img" 2>/dev/null || tools/android-tools/simg2img "$SUPER_FILE" "super.raw.img"
    SUPER_FILE="super.raw.img"
  fi
  mkdir -p super_dump
  tools/android-tools/lpunpack "$SUPER_FILE" super_dump 2>/dev/null
  SYSTEM_IMG=$(find super_dump -name "system.img" -o -name "system_a.img" | head -n 1)
  PRODUCT_IMG=$(find super_dump -name "product.img" -o -name "product_a.img" | head -n 1)
else
  SYSTEM_IMG=$(find . -maxdepth 1 -name "system.img.lz4" -o -name "system.img" | head -n 1)
  if [[ "$SYSTEM_IMG" == *.lz4 ]]; then
    lz4 -d "$SYSTEM_IMG" "system_raw.img" 2>/dev/null
    SYSTEM_IMG="system_raw.img"
  fi
  if [ -n "$SYSTEM_IMG" ] && file "$SYSTEM_IMG" 2>/dev/null | grep -q "sparse"; then
    simg2img "$SYSTEM_IMG" "system_unsparse.img" 2>/dev/null
    SYSTEM_IMG="system_unsparse.img"
  fi
  PRODUCT_IMG=$(find . -maxdepth 1 -name "product.img.lz4" -o -name "product.img" | head -n 1)
  if [[ "$PRODUCT_IMG" == *.lz4 ]]; then
    lz4 -d "$PRODUCT_IMG" "product_raw.img" 2>/dev/null
    PRODUCT_IMG="product_raw.img"
  fi
  if [ -n "$PRODUCT_IMG" ] && file "$PRODUCT_IMG" 2>/dev/null | grep -q "sparse"; then
    simg2img "$PRODUCT_IMG" "product_unsparse.img" 2>/dev/null
    PRODUCT_IMG="product_unsparse.img"
  fi
fi

mkdir -p galaxy_ai/system/priv-app
mkdir -p galaxy_ai/system/app

echo ""; echo "[5/6] Extracting selected features..."

copy_feature() {
  local SEARCH_TERM="$1"
  local SEARCH_DIR="$2"
  local SUBDIR="$3"
  local LABEL="$4"
  
  local FOUND_DIR=$(find "$SEARCH_DIR" -maxdepth 4 -type d -path "*/${SUBDIR}/${SEARCH_TERM}*" 2>/dev/null | head -1)
  if [ -n "$FOUND_DIR" ] && [ -d "$FOUND_DIR" ]; then
    local FOLDER_NAME=$(basename "$FOUND_DIR")
    mkdir -p "galaxy_ai/system/${SUBDIR}/$FOLDER_NAME"
    cp -r "$FOUND_DIR"/* "galaxy_ai/system/${SUBDIR}/$FOLDER_NAME/"
    echo "    ✓ $FOLDER_NAME ($LABEL)"
    return 0
  fi
  return 1
}

if [ -n "$SYSTEM_IMG" ] && [ -f "$SYSTEM_IMG" ]; then
  mkdir -p system_extracted
  if tools/erofs-utils/extract.erofs -i "$SYSTEM_IMG" -x -o system_extracted/ >/dev/null 2>&1; then
    echo "  ✅ System extracted via erofs"
  else
    echo "  erofs failed - trying debugfs..."
    for FEAT in $PRIV_FEATURES; do
      for SRC_PATH in "priv-app" "system/priv-app"; do
        if debugfs -R "ls $SRC_PATH" "$SYSTEM_IMG" 2>/dev/null | grep -q "$FEAT"; then
          MATCHING=$(debugfs -R "ls $SRC_PATH" "$SYSTEM_IMG" 2>/dev/null | grep "$FEAT" | awk '{print $NF}' | head -1)
          mkdir -p "system_extracted/priv-app/$MATCHING"
          debugfs -R "rdump $SRC_PATH/$MATCHING system_extracted/priv-app/$MATCHING" "$SYSTEM_IMG" 2>/dev/null
        fi
      done
    done
    for FEAT in $APP_FEATURES; do
      for SRC_PATH in "app" "system/app"; do
        if debugfs -R "ls $SRC_PATH" "$SYSTEM_IMG" 2>/dev/null | grep -q "$FEAT"; then
          MATCHING=$(debugfs -R "ls $SRC_PATH" "$SYSTEM_IMG" 2>/dev/null | grep "$FEAT" | awk '{print $NF}' | head -1)
          mkdir -p "system_extracted/app/$MATCHING"
          debugfs -R "rdump $SRC_PATH/$MATCHING system_extracted/app/$MATCHING" "$SYSTEM_IMG" 2>/dev/null
        fi
      done
    done
  fi

  for FEAT in $PRIV_FEATURES; do
    copy_feature "$FEAT" "system_extracted" "priv-app" "system/priv-app" || true
  done
  for FEAT in $APP_FEATURES; do
    copy_feature "$FEAT" "system_extracted" "app" "system/app" || true
  done
  rm -rf system_extracted
fi

if [ -n "$PRODUCT_IMG" ] && [ -f "$PRODUCT_IMG" ]; then
  mkdir -p product_extracted
  if tools/erofs-utils/extract.erofs -i "$PRODUCT_IMG" -x -o product_extracted/ >/dev/null 2>&1; then
    echo "  ✅ Product extracted via erofs"
  else
    echo "  product erofs failed - trying debugfs..."
    for FEAT in $PRIV_FEATURES; do
      for SRC_PATH in "priv-app" "product/priv-app"; do
        if debugfs -R "ls $SRC_PATH" "$PRODUCT_IMG" 2>/dev/null | grep -q "$FEAT"; then
          MATCHING=$(debugfs -R "ls $SRC_PATH" "$PRODUCT_IMG" 2>/dev/null | grep "$FEAT" | awk '{print $NF}' | head -1)
          mkdir -p "product_extracted/priv-app/$MATCHING"
          debugfs -R "rdump $SRC_PATH/$MATCHING product_extracted/priv-app/$MATCHING" "$PRODUCT_IMG" 2>/dev/null
        fi
      done
    done
    for FEAT in $APP_FEATURES; do
      for SRC_PATH in "app" "product/app"; do
        if debugfs -R "ls $SRC_PATH" "$PRODUCT_IMG" 2>/dev/null | grep -q "$FEAT"; then
          MATCHING=$(debugfs -R "ls $SRC_PATH" "$PRODUCT_IMG" 2>/dev/null | grep "$FEAT" | awk '{print $NF}' | head -1)
          mkdir -p "product_extracted/app/$MATCHING"
          debugfs -R "rdump $SRC_PATH/$MATCHING product_extracted/app/$MATCHING" "$PRODUCT_IMG" 2>/dev/null
        fi
      done
    done
  fi

  for FEAT in $PRIV_FEATURES; do
    FOUND_DIR=$(find product_extracted -maxdepth 4 -type d -path "*/priv-app/${FEAT}*" 2>/dev/null | head -1)
    if [ -n "$FOUND_DIR" ] && [ -d "$FOUND_DIR" ]; then
      FOLDER_NAME=$(basename "$FOUND_DIR")
      mkdir -p "galaxy_ai/system/priv-app/$FOLDER_NAME"
      cp -r "$FOUND_DIR"/* "galaxy_ai/system/priv-app/$FOLDER_NAME/"
      echo "    ✓ $FOLDER_NAME (product/priv-app)"
    fi
  done
  for FEAT in $APP_FEATURES; do
    FOUND_DIR=$(find product_extracted -maxdepth 4 -type d -path "*/app/${FEAT}*" 2>/dev/null | head -1)
    if [ -n "$FOUND_DIR" ] && [ -d "$FOUND_DIR" ]; then
      FOLDER_NAME=$(basename "$FOUND_DIR")
      mkdir -p "galaxy_ai/system/app/$FOLDER_NAME"
      cp -r "$FOUND_DIR"/* "galaxy_ai/system/app/$FOLDER_NAME/"
      echo "    ✓ $FOLDER_NAME (product/app)"
    fi
  done
  rm -rf product_extracted
fi

rm -rf super_dump super.img super.raw.img system_unsparse.img product_raw.img product_unsparse.img system_raw.img

echo ""; echo "[6/6] Packaging..."
cd galaxy_ai
zip -r ../GalaxyAI.zip . >/dev/null 2>&1
cd ..
mv GalaxyAI.zip output/ 2>/dev/null || { mkdir -p output && mv GalaxyAI.zip output/; }
rm -rf galaxy_ai

echo ""; echo "═══════════════════════════════════════"
echo "✅ GalaxyAI.zip ready"
echo "Total size: $(du -h output/GalaxyAI.zip | cut -f1)"
echo "═══════════════════════════════════════"
echo "✅ Done!"
