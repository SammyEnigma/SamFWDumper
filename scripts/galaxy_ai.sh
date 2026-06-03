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
ZIP_TYPE="${2:-galaxyai}"

# Shift first 2 args, rest are feature selections
shift 2

chmod +x tools/android-tools/* tools/erofs-utils/* 2>/dev/null || true

# Build list of selected features
SELECTED_FEATURES=""
for FEAT in "$@"; do
  [ "$FEAT" = "true" ] && continue  # skip the argument labels, we handle by position
done

# We'll parse the arguments properly below
FEATURES_LIST=""
[ "${1}" = "true" ] && FEATURES_LIST="$FEATURES_LIST AlKernel"
[ "${2}" = "true" ] && FEATURES_LIST="$FEATURES_LIST BixbyInterpreter"
[ "${3}" = "true" ] && FEATURES_LIST="$FEATURES_LIST MediaSearch"
[ "${4}" = "true" ] && FEATURES_LIST="$FEATURES_LIST Moments"
[ "${5}" = "true" ] && FEATURES_LIST="$FEATURES_LIST OfflineLanguageModel_stub"
[ "${6}" = "true" ] && FEATURES_LIST="$FEATURES_LIST PhotoEditor_AFull"
[ "${7}" = "true" ] && FEATURES_LIST="$FEATURES_LIST SamsungGallery2018"
[ "${8}" = "true" ] && FEATURES_LIST="$FEATURES_LIST SamsungSmartSuggestions"
[ "${9}" = "true" ] && FEATURES_LIST="$FEATURES_LIST SecSettingsIntelligence"
[ "${10}" = "true" ] && FEATURES_LIST="$FEATURES_LIST SemanticSearchCore"
[ "${11}" = "true" ] && FEATURES_LIST="$FEATURES_LIST SpriteWallpaper"
[ "${12}" = "true" ] && FEATURES_LIST="$FEATURES_LIST StoryService"
[ "${13}" = "true" ] && FEATURES_LIST="$FEATURES_LIST VisionModel-Stub"
[ "${14}" = "true" ] && FEATURES_LIST="$FEATURES_LIST WallpaperMagician-Stub"
FEATURES_LIST="${FEATURES_LIST# }"

if [ -z "$FEATURES_LIST" ]; then
  echo "❌ No features selected!"
  exit 1
fi

echo "Zip type: $ZIP_TYPE"
echo "Selected features: $FEATURES_LIST"

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

# Build output structure
mkdir -p galaxy_ai/system/priv-app

echo ""; echo "[5/6] Extracting selected features..."

# Extract from system.img
if [ -n "$SYSTEM_IMG" ] && [ -f "$SYSTEM_IMG" ]; then
  mkdir -p system_extracted
  if tools/erofs-utils/extract.erofs -i "$SYSTEM_IMG" -x -o system_extracted/ >/dev/null 2>&1; then
    echo "  ✅ System extracted via erofs"
  else
    echo "  erofs failed - trying debugfs..."
    for FEAT in $FEATURES_LIST; do
      for SRC_PATH in "priv-app/$FEAT" "system/priv-app/$FEAT"; do
        if debugfs -R "ls $SRC_PATH" "$SYSTEM_IMG" 2>/dev/null | grep -q .; then
          mkdir -p "system_extracted/priv-app/$FEAT"
          debugfs -R "rdump $SRC_PATH system_extracted/priv-app/$FEAT" "$SYSTEM_IMG" 2>/dev/null
          break
        fi
      done
    done
  fi

  # Copy selected priv-app folders
  for FEAT in $FEATURES_LIST; do
    FOUND=false
    for BASE in \
      "system_extracted/priv-app/$FEAT" \
      "system_extracted/system/priv-app/$FEAT" \
      "system_extracted/system_a/priv-app/$FEAT" \
      "system_extracted/system/system/priv-app/$FEAT" \
      "system_extracted/system_a/system/priv-app/$FEAT"; do
      if [ -d "$BASE" ]; then
        cp -r "$BASE" "galaxy_ai/system/priv-app/"
        echo "    ✓ $FEAT (system)"
        FOUND=true
        break
      fi
    done
  done
  rm -rf system_extracted
fi

# Extract from product.img
if [ -n "$PRODUCT_IMG" ] && [ -f "$PRODUCT_IMG" ]; then
  mkdir -p product_extracted
  if tools/erofs-utils/extract.erofs -i "$PRODUCT_IMG" -x -o product_extracted/ >/dev/null 2>&1; then
    echo "  ✅ Product extracted via erofs"
  else
    echo "  product erofs failed - trying debugfs..."
    for FEAT in $FEATURES_LIST; do
      for SRC_PATH in "priv-app/$FEAT" "product/priv-app/$FEAT"; do
        if debugfs -R "ls $SRC_PATH" "$PRODUCT_IMG" 2>/dev/null | grep -q .; then
          mkdir -p "product_extracted/priv-app/$FEAT"
          debugfs -R "rdump $SRC_PATH product_extracted/priv-app/$FEAT" "$PRODUCT_IMG" 2>/dev/null
          break
        fi
      done
    done
  fi

  for FEAT in $FEATURES_LIST; do
    for BASE in \
      "product_extracted/priv-app/$FEAT" \
      "product_extracted/product/priv-app/$FEAT" \
      "product_extracted/product_a/priv-app/$FEAT" \
      "product_extracted/product_b/priv-app/$FEAT"; do
      if [ -d "$BASE" ]; then
        mkdir -p "galaxy_ai/system/priv-app/$FEAT"
        cp -r "$BASE"/* "galaxy_ai/system/priv-app/$FEAT/"
        echo "    ✓ $FEAT (product)"
        break
      fi
    done
  done
  rm -rf product_extracted
fi

rm -rf super_dump super.img super.raw.img system_unsparse.img product_raw.img product_unsparse.img system_raw.img

echo ""; echo "[6/6] Packaging..."
cd galaxy_ai
zip -r ../GalaxyAI.zip . >/dev/null 2>&1
cd ..
mv GalaxyAI.zip output/ 2>/dev/null || mkdir -p output && mv GalaxyAI.zip output/
rm -rf galaxy_ai

echo ""; echo "═══════════════════════════════════════"
echo "✅ GalaxyAI.zip ready"
echo "Total size: $(du -h output/GalaxyAI.zip | cut -f1)"
echo "═══════════════════════════════════════"
echo "✅ Done!"
