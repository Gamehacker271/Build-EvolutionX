#!/bin/bash

# ================================
# Colors
# ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ================================
# Terminal Setup
# ================================
echo -en "\033[?25l"  # hide cursor
trap 'echo -en "\033[?12l\033[?25h"' EXIT  # restore on exit

# ================================
# Helper Functions
# ================================
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR] ${timestamp} - ${message}${RESET}" >&2
    exit "$exit_code"
}

print_header() {
    local message="$1"
    local border_char="${2:-=}"
    local color="${3:-$GREEN}"
    local length=${#message}
    local border=$(printf "%${length}s" | tr " " "$border_char")
    echo -e "${color}${border}${RESET}"
    echo -e "${color}${message}${RESET}"
    echo -e "${color}${border}${RESET}"
}

# ================================
# Audio Mod Integration (Hardware Level)
# ================================
integrar_viperfx() {
    clear
    local ROOT_DIR="${ANDROID_ROOT:-$(pwd)}"
    local V4A_REPO="https://github.com/TogoFire/packages_apps_ViPER4AndroidFX"
    local V4A_BRANCH="v4a"
    local V4A_DIR="$ROOT_DIR/packages/apps/ViPER4AndroidFX"
    local DEVICE_MK="$ROOT_DIR/device/xiaomi/sapphire/device.mk"
    local AUDIO_EFFECTS_XML="$ROOT_DIR/device/xiaomi/sapphire/configs/audio/audio_effects.xml"
    local AUDIOSERVER_TE="$ROOT_DIR/device/xiaomi/sapphire/sepolicy/vendor/audioserver.te"

    echo "=== Iniciando integracao do ViPER4AndroidFX ==="

    if [ -d "$V4A_DIR" ]; then
        echo "[AVISO] $V4A_DIR ja existe, pulando clone"
    else
        git clone --depth 1 -b "$V4A_BRANCH" "$V4A_REPO" "$V4A_DIR" || return 1
        echo "[OK] Repositorio clonado em $V4A_DIR"
    fi

    if [ -f "$DEVICE_MK" ]; then
        if ! grep -q "ViPER4AndroidFX/config.mk" "$DEVICE_MK"; then
            echo "" >> "$DEVICE_MK"
            echo "# ViPER4AndroidFX" >> "$DEVICE_MK"
            echo '$(call inherit-product, packages/apps/ViPER4AndroidFX/config.mk)' >> "$DEVICE_MK"
            echo "[OK] inherit-product adicionado ao device.mk"
        fi
    fi

    if [ -f "$AUDIO_EFFECTS_XML" ]; then
        if ! grep -q "v4a_re" "$AUDIO_EFFECTS_XML"; then
            sed -i 's|</libraries>|    <library name="v4a_re" path="libv4a_re.so"/>\n</libraries>|' "$AUDIO_EFFECTS_XML" 2>/dev/null
            sed -i 's|</effects>|    <effect name="v4a_standard_re" library="v4a_re" uuid="90380da3-8536-4744-a6a3-5731970e640f"/>\n</effects>|' "$AUDIO_EFFECTS_XML" 2>/dev/null
        fi
    fi

    mkdir -p "$(dirname "$AUDIOSERVER_TE")"
    if [ -f "$AUDIOSERVER_TE" ] && grep -q "ViperFX" "$AUDIOSERVER_TE"; then
        echo "[AVISO] regras do ViperFX ja presentes"
    else
        {
            echo ""
            echo "# ViperFX / ViPER4Android FX"
            echo "get_prop(audioserver, vendor_audio_prop)"
            echo "allow audioserver unlabeled:file { read write open getattr };"
            echo "allow hal_audio_default hal_audio_default:process { execmem };"
        } >> "$AUDIOSERVER_TE"
    fi
    
    desativar_a2dp_offload() {
        local VENDOR_PROP
        VENDOR_PROP=$(find "$ROOT_DIR/device/xiaomi" -iname "vendor.prop" 2>/dev/null | head -n 1)
        [ -z "$VENDOR_PROP" ] && return 1
        sed -i "s/^persist.bluetooth.a2dp_offload.disabled=.*/persist.bluetooth.a2dp_offload.disabled=true/" "$VENDOR_PROP"
        return 0
    }
    desativar_a2dp_offload || true

    echo "=== Integracao do ViPER4AndroidFX concluida ==="
    return 0
}

gofile_install(){
    echo -e "${CYAN}Installing gofile upload tool...${RESET}"
    wget -q https://raw.githubusercontent.com/kenway214/GoFile-Upload-Script/master/upload.sh \
        -O ./gofile && chmod +x ./gofile
}

# ================================
# Adapting Lineage Tree to EvoX
# ================================

 # ================================
# Adapting Lineage Tree to EvoX
# ================================
adaptar_tree() {
    echo -e "${YELLOW}Adapting LineageOS Device Tree for EvolutionX...${RESET}"
    local DEV_PATH="device/xiaomi/sapphire"
    
    # 1. Renombrar el archivo principal .mk
    if [ -f "$DEV_PATH/lineage_sapphire.mk" ]; then
        mv "$DEV_PATH/lineage_sapphire.mk" "$DEV_PATH/evolution_sapphire.mk"
        echo -e "${GREEN}-> Renamed lineage_sapphire.mk to evolution_sapphire.mk${RESET}"
    fi
    
    # 2. Actualizar SOLO el nombre del producto, dejando la ruta de vendor intacta
    if [ -f "$DEV_PATH/evolution_sapphire.mk" ]; then
        sed -i 's/lineage_sapphire/evolution_sapphire/g' "$DEV_PATH/evolution_sapphire.mk"
        echo -e "${GREEN}-> Patched PRODUCT_NAME in evolution_sapphire.mk${RESET}"
    fi

    # 3. Actualizar AndroidProducts.mk para que el sistema encuentre el nuevo lunch
    if [ -f "$DEV_PATH/AndroidProducts.mk" ]; then
        sed -i 's/lineage_sapphire/evolution_sapphire/g' "$DEV_PATH/AndroidProducts.mk"
        echo -e "${GREEN}-> Patched AndroidProducts.mk${RESET}"
    fi
}

# ================================
# Main Script Execution
# ================================
echo -e "${RED}Starting EvolutionX 15 (vic) build script...${RESET}"
echo -e "${YELLOW}Working in current directory: $PWD${RESET}"

echo -e "${CYAN}Initializing repo (Android 15 / vic)...${RESET}"
repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs --depth=1 || error_exit "Repo init failed"
print_header "Repo init success"

echo -e "${GREEN}Generating Local Manifest for Sapphire (The Angel Place)...${RESET}"
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/sapphire.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="theangelplace" fetch="https://github.com/The-Angel-Place-Sapphire" />

    <!-- Device Trees -->
    <project path="device/xiaomi/sapphire-kernel" name="device_xiaomi_sapphire-kernel" remote="theangelplace" revision="lineage-23.2" />
    <project path="device/xiaomi/sepolicy" name="device_xiaomi_sepolicy" remote="theangelplace" revision="16" />
    <project path="device/xiaomi/sapphire" name="device_xiaomi_sapphire" remote="theangelplace" revision="lineage-23.2" />
    <project path="vendor/xiaomi/sapphire" name="vendor_xiaomi_sapphire" remote="theangelplace" revision="lineage-23.2" />
    <project path="hardware/xiaomi" name="android_hardware_xiaomi" remote="theangelplace" revision="lineage-23.2" />

    <!-- HALs -->
    <project path="hardware/qcom-caf/sm6225/audio/agm" name="vendor_qcom_opensource_agm" remote="theangelplace" revision="lineage-22.2-caf-sm6225" />
    <project path="hardware/qcom-caf/sm6225/audio/pal" name="vendor_qcom_opensource_arpal-lx" remote="theangelplace" revision="lineage-22.0-caf-sm6225" />
    <project path="hardware/qcom-caf/sm6225/data-ipa-cfg-mgr" name="vendor_qcom_opensource_data-ipa-cfg-mgr" remote="theangelplace" revision="lineage-22.0-caf-sm6225" />
    <project path="hardware/qcom-caf/sm6225/dataipa" name="vendor_qcom_opensource_dataipa" remote="theangelplace" revision="lineage-22.0-caf-sm6225" />
    <project path="hardware/qcom-caf/sm6225/display" name="hardware_qcom_display" remote="theangelplace" revision="lineage-22.0-caf-sm6225" />
    <project path="hardware/qcom-caf/sm6225/media" name="hardware_qcom_media" remote="theangelplace" revision="lineage-22.0-caf-sm6225" />
    <project path="hardware/qcom-caf/sm6225/audio/primary-hal" name="hardware_qcom_audio" remote="theangelplace" revision="lineage-22.0-caf-sm6225" />
    <project path="device/qcom/sepolicy_vndr/sm6225" name="device_qcom_sepolicy_vndr" remote="theangelplace" revision="lineage-23.0-caf-sm6225" />
</manifest>
EOF

echo -e "${YELLOW}Resolving potential vendor/gms conflicts...${RESET}"
sed -i '/path="vendor\/gms"/d' .repo/local_manifests/*.xml 2>/dev/null || true
sed -i '/name="gitlab.com\/MindTheGapps\/vendor_gms"/d' .repo/local_manifests/*.xml 2>/dev/null || true
print_header "Manifest generation and patching success"

clear
echo -e "${RED}Syncing full repo (Restricted to 24 jobs to prevent blocks)...${RESET}"
repo sync -c -j24 --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune || error_exit "Repo sync failed"
print_header "Repo sync success"

clear
adaptar_tree
integrar_viperfx
gofile_install

clear
echo -e "${CYAN}Setting up build environment...${RESET}"
source build/envsetup.sh
export BUILD_USERNAME=Gamehac_RA
export BUILD_HOSTNAME=EvolutionX
export SKIP_ABI_CHECKS=true
mkdir -p out/target/product/sapphire/obj/KERNEL_OBJ/usr
print_header "Build environment ready"

clear
echo -e "${RED}Starting build...${RESET}"
lunch evolution_sapphire-userdebug || error_exit "Lunch failed"
m evolution || error_exit "Build failed"

upload(){
    BUILD_DIR="out/target/product/sapphire"
    GOFILE_SCRIPT="./gofile"
    ROM_URL=""

    if [ ! -d "$BUILD_DIR" ]; then
        echo -e "${RED}[ERROR] Build directory not found: $BUILD_DIR${RESET}"
        return 1
    fi

    ROM_NAME=$(ls -t "$BUILD_DIR" 2>/dev/null | grep -i "evolution_sapphire.*\.zip$" | head -n 1)

    if [ -n "$ROM_NAME" ]; then
        ROM_PATH="$BUILD_DIR/$ROM_NAME"
        ROM_SIZE=$(du -h "$ROM_PATH" | cut -f1)
        
        if [ -x "$GOFILE_SCRIPT" ]; then
            ROM_OUTPUT=$("$GOFILE_SCRIPT" "$ROM_PATH" 2>&1)
            UPLOAD_EXIT=$?
            if [ $UPLOAD_EXIT -eq 0 ]; then
                ROM_URL=$(echo "$ROM_OUTPUT" | grep -oP 'https?://[^\s]+' | head -n1)
            fi
        fi
    else
        echo -e "${YELLOW}ROM not found in $BUILD_DIR. Upload skipped.${RESET}"
        return 1
    fi

    print_header "Upload complete"
    echo -e "${CYAN}ROM:${RESET} ${ROM_NAME:-N/A}"
    echo -e "${CYAN}Size:${RESET} ${ROM_SIZE:-N/A}"
    if [ -n "$ROM_URL" ]; then
        echo -e "${CYAN}Link:${RESET} $ROM_URL"
    fi
}

upload
