#!/usr/bin/env bash
# SWARM_OS Companion Image Exporter Script

SRC_DIR="/home/i320k3n/.gemini/antigravity-ide/brain/c3f5f88d-0dcf-4e2a-828f-9b3a71e9c873"
APP_DRAWABLE="/home/i320k3n/Desktop/swarm_os-companion/app/src/main/res/drawable"
APP_ASSETS="/home/i320k3n/Desktop/swarm_os-companion/assets"

mkdir -p "$APP_DRAWABLE"
mkdir -p "$APP_ASSETS"

echo "Copying all generated 8K images & rEFInd boot icons..."

cp -v "$SRC_DIR/lucilla_ai_goddess_1785205474963.png" "$APP_DRAWABLE/lucilla_ai_goddess.png"
cp -v "$SRC_DIR/lucilla_ai_goddess_1785205474963.png" "$APP_ASSETS/lucilla_ai_goddess.png"

cp -v "$SRC_DIR/dr_i3oltz_3d_avatar_1785206753086.png" "$APP_DRAWABLE/dr_i3oltz_3d_avatar.png"
cp -v "$SRC_DIR/dr_i3oltz_3d_avatar_1785206753086.png" "$APP_ASSETS/dr_i3oltz_3d_avatar.png"

cp -v "$SRC_DIR/refind_icon_swarm_os_1785206908610.png" "$APP_DRAWABLE/refind_icon_swarm_os.png"
cp -v "$SRC_DIR/refind_icon_swarm_os_1785206908610.png" "$APP_ASSETS/refind_icon_swarm_os.png"

cp -v "$SRC_DIR/refind_icon_endeavouros_1785206918909.png" "$APP_DRAWABLE/refind_icon_endeavouros.png"
cp -v "$SRC_DIR/refind_icon_endeavouros_1785206918909.png" "$APP_ASSETS/refind_icon_endeavouros.png"

cp -v "$SRC_DIR/refind_icon_cachyos_1785206929708.png" "$APP_DRAWABLE/refind_icon_cachyos.png"
cp -v "$SRC_DIR/refind_icon_cachyos_1785206929708.png" "$APP_ASSETS/refind_icon_cachyos.png"

echo "✅ All 5 images successfully exported to swarm_os-companion!"
