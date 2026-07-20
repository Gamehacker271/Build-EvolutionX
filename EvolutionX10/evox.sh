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

check_repo_valid() {
    local repo_dir="$HOME/.repo"
    if [ -d "$repo_dir" ]; then
        echo "[ERROR] $repo_dir found — leftover workspace in home directory"
        error_exit "Remove or move $repo_dir before continuing (rm -rf $repo_dir)"
    fi
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

cleanup_repos() {
    echo -e "${YELLOW}Performing cleanup...${RESET}"
    rm -rf .repo/local_manifests/
    rm -rf hardware/qcom-caf/common
    print_header "Cleanup completed"
}

clone_repo() {
    local repo_url=$1
    local branch=$2
    local dest=$3
    echo -e "${CYAN}Cloning $dest...${RESET}"
    [ -d "$dest" ] && rm -rf "$dest"
    git clone --depth 1 -b "$branch" "$repo_url" "$dest" || error_exit "Failed to clone $dest"
    print_header "$dest clone success"
}

clone_hal() {
    local url=$1
    local path=$2
    local branch=$3
    rm -rf "$path"
    git clone --depth 1 -b "$branch" "$url" "$path" || error_exit "Failed to clone HAL $path"
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

# ================================
# Workspace Setup
# ================================
setup_evo_dir() {
    EVO_DIR="EvolutionX-A15"
    TARGET_DIR="$HOME/$EVO_DIR"

    if [ "$(basename "$PWD")" != "$EVO_DIR" ]; then
        echo -e "${CYAN}Not in $EVO_DIR directory. Checking/Creating...${RESET}"
        if [ -d "$TARGET_DIR" ]; then
            cd "$TARGET_DIR" || error_exit "Failed to cd to $TARGET_DIR"
        else
            mkdir -p "$TARGET_DIR" || error_exit "Failed to create $TARGET_DIR"
            cd "$TARGET_DIR" || error_exit "Failed to cd to $TARGET_DIR"
        fi
    fi
}

gofile_install(){
    echo -e "${CYAN}Installing gofile upload tool...${RESET}"
    wget -q https://raw.githubusercontent.com/kenway214/GoFile-Upload-Script/master/upload.sh \
        -O ~/EvolutionX-A15/gofile && chmod +x ~/EvolutionX-A15/gofile
    if ! grep -q 'alias gofile' ~/.bashrc; then
        echo 'alias gofile="~/EvolutionX-A15/gofile"' >> ~/.bashrc
    fi
    source ~/.bashrc 2>/dev/null || true
}

# ================================
# Main Script Execution
# ================================
check_repo_valid
setup_evo_dir

echo -e "${RED}Starting EvolutionX 15 (vic) build script...${RESET}"
cleanup_repos

echo -e "${CYAN}Initializing repo (Android 15 / vic)...${RESET}"
repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs --depth=1 || error_exit "Repo init failed"
print_header "Repo init success"

echo -e "${GREEN}Cloning Sapphire Device Tree...${RESET}"
clone_repo "https://github.com/saroj-nokia/local_manifests_sapphire" "sapphire15" ".repo/local_manifests"

# === AGREGAR ESTO PARA EVITAR EL DUPLICADO DE VENDOR/GMS ===
if [ -d ".repo/local_manifests" ]; then
    echo -e "${YELLOW}Borrando definiciones duplicadas de vendor/gms...${RESET}"
    find .repo/local_manifests/ -name "*.xml" -type f -exec sed -i '/path="vendor\/gms"/d' {} +
fi

clear
echo -e "${RED}Syncing full repo...${RESET}"
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune || error_exit "Repo sync failed"
print_header "Repo sync success"

echo -e "${RED}Cloning HALs for SM6225...${RESET}"
clone_hal "https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git" "hardware/qcom-caf/common" "lineage-22.2"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git" "hardware/qcom-caf/sm6225/audio/agm" "lineage-22.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_arpal-lx.git" "hardware/qcom-caf/sm6225/audio/pal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git" "hardware/qcom-caf/sm6225/data-ipa-cfg-mgr" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git" "hardware/qcom-caf/sm6225/dataipa" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_display.git" "hardware/qcom-caf/sm6225/display" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_media.git" "hardware/qcom-caf/sm6225/media" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_audio.git" "hardware/qcom-caf/sm6225/audio/primary-hal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/device_qcom_sepolicy_vndr.git" "device/qcom/sepolicy_vndr/sm6225" "lineage-22.0-caf-sm6225"
print_header "HALs cloned"

clear
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
    GOFILE_SCRIPT="${HOME}/EvolutionX-A15/gofile"
    ROM_URL=""

    if [ ! -d "$BUILD_DIR" ]; then
        echo -e "${RED}[ERROR] Build directory not found: $BUILD_DIR${RESET}"
        return 1
    fi

    # Modified Regex to catch EvolutionX output zips
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
