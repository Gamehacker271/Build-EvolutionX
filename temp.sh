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
# Global Variables (Melhoria 4)
# ================================
TARGET_DIR=""
WAS_CREATED_BY_US=false

# ================================
# Cleanup on exit (Melhoria 4)
# ================================
cleanup_on_exit() {
    if [ "$WAS_CREATED_BY_US" = true ] && [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}[!] Cleaning up created directory: $TARGET_DIR${RESET}"
        cd "$HOME" || return
        rm -rf "$TARGET_DIR"
        echo -e "${GREEN}[✓] Cleanup complete${RESET}"
    fi
}
trap cleanup_on_exit EXIT INT TERM

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

cleanup_repos() {
    echo -e "${YELLOW}Performing cleanup...${RESET}"
    rm -rf .repo/local_manifests/
    rm -rf hardware/qcom-caf/common
    rm -rf packages/apps/ThemePicker
    rm -rf vendor/qcom/opensource/healthd-ext
    rm -rf vendor/lineage
    print_header "Cleanup completed"
    sleep 0.5
    clear
}

# Melhoria 2: clone_repo melhorada
clone_repo() {
    local repo_url=$1
    local branch=$2
    local dest=$3
    
    echo -e "${CYAN}Cloning $dest...${RESET}"
    
    # Remove diretório se existir para evitar conflitos
    [ -d "$dest" ] && rm -rf "$dest"
    
    git clone --depth 1 -b "$branch" "$repo_url" "$dest" || error_exit "Failed to clone $dest"
    
    print_header "$dest clone success"
    sleep 0.5
    clear
}

clone_hal() {
    local url=$1
    local path=$2
    local branch=$3
    rm -rf "$path"
    git clone --depth 1 -b "$branch" "$url" "$path" || error_exit "Failed to clone HAL $path"
}

# Melhoria 7: add_to_device_mk
add_to_device_mk() {
    local package=$1
    local device_mk="device/xiaomi/sapphire/device.mk"
    
    if [ ! -f "$device_mk" ]; then
        echo -e "${YELLOW}device.mk not found, skipping $package addition${RESET}"
        return
    fi
    
    if ! grep -q "^PRODUCT_PACKAGES += $package$" "$device_mk"; then
        echo "PRODUCT_PACKAGES += $package" >> "$device_mk"
        print_header "$package added to device.mk"
    else
        echo -e "${YELLOW}$package already exists in device.mk${RESET}"
    fi
}

# Melhoria 5: patch_signature_spoofing
patch_signature_spoofing() {
    local COMPUTER_ENGINE="frameworks/base/services/core/java/com/android/server/pm/ComputerEngine.java"
    
    if [ ! -f "$COMPUTER_ENGINE" ]; then
        echo -e "${YELLOW}ComputerEngine.java not found, skipping patch${RESET}"
        return
    fi
    
    # Backup original
    cp "$COMPUTER_ENGINE" "${COMPUTER_ENGINE}.backup"
    
    if grep -q 'if (!isDebuggable())' "$COMPUTER_ENGINE"; then
        sed -i '/if (!isDebuggable()) {/{N;N;d}' "$COMPUTER_ENGINE"
        print_header "Signature Spoofing patch applied"
    else
        echo -e "${YELLOW}Signature Spoofing patch: block not found or already patched${RESET}"
    fi
}

# Melhoria 9: patch_version_mk
patch_version_mk() {
    local version_mk="vendor/lineage/config/version.mk"
    
    if [ ! -f "$version_mk" ]; then
        echo -e "${YELLOW}version.mk not found, skipping MicroG suffix patch${RESET}"
        return
    fi
    
    # Backup
    cp "$version_mk" "${version_mk}.backup"
    
    # Verifica se já está patcheado
    if grep -q "MICROG" "$version_mk"; then
        echo -e "${YELLOW}MicroG suffix already patched${RESET}"
        return
    fi
    
    # Aplica o patch de forma mais segura
    cat >> "$version_mk" << 'EOF'

# Add MICROG to suffix if WITH_GMS is true
ifeq ($(WITH_GMS),true)
    LINEAGE_VERSION_SUFFIX := $(LINEAGE_VERSION_SUFFIX)-MICROG
endif
EOF
    
    print_header "MicroG suffix patch applied"
}

# ================================
# Check/Create LineageOS-MicroG directory
# ================================
setup_lineage_dir() {
    LINEAGE_DIR="LineageOS-MicroG"
    TARGET_DIR="$HOME/$LINEAGE_DIR"
    
    cd_or_exit() {
        cd "$1" || error_exit "Failed to cd to $1"
    }
    
    if [ "$(basename "$PWD")" != "$LINEAGE_DIR" ]; then
        echo -e "${CYAN}Not in $LINEAGE_DIR directory. Checking/Creating...${RESET}"
        
        if [ -d "$TARGET_DIR" ]; then
            cd_or_exit "$TARGET_DIR"
            echo -e "${GREEN}Changed to existing directory: $PWD${RESET}"
        else
            echo -e "${YELLOW}Creating $TARGET_DIR...${RESET}"
            mkdir -p "$TARGET_DIR" || error_exit "Failed to create $TARGET_DIR"
            WAS_CREATED_BY_US=true  # Melhoria 4
            cd_or_exit "$TARGET_DIR"
            echo -e "${GREEN}Created and changed to: $PWD${RESET}"
        fi
        sleep 1
    else
        echo -e "${GREEN}Already in $LINEAGE_DIR directory: $PWD${RESET}"
    fi
}

# ================================
# Main Script
# ================================
setup_lineage_dir

echo -e "${CYAN}Starting LOS 23.2 build script...${RESET}"
cleanup_repos

# ================================
# Initialize LOS repo
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs || error_exit "Repo init failed"
print_header "Repo init success"

# ================================
# Clone local manifests
clone_repo "https://github.com/saroj-nokia/local_manifests_sapphire" "sapphire16" ".repo/local_manifests"

# Create MicroG manifest
echo -e "${CYAN}Creating MicroG manifest...${RESET}"
cat > .repo/local_manifests/microg.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="lineageos4microg" fetch="https://github.com/lineageos4microg/" />
    <project path="vendor/partner_gms" name="android_vendor_partner_gms" remote="lineageos4microg" revision="master" />
</manifest>
EOF
print_header "MicroG manifest created"

# Sync MicroG vendor
echo -e "${CYAN}Syncing MicroG vendor...${RESET}"
repo sync vendor/partner_gms || error_exit "Failed to sync MicroG vendor"
print_header "MicroG vendor synced"

# Sync repo
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j14 || error_exit "Repo sync failed"
print_header "Repo sync success"

# Clone HALs
echo -e "${CYAN}Cloning HALs for SM6225...${RESET}"
clone_hal "https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git" "hardware/qcom-caf/common" "lineage-23.2"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git" "hardware/qcom-caf/sm6225/audio/agm" "lineage-22.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_arpal-lx.git" "hardware/qcom-caf/sm6225/audio/pal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git" "hardware/qcom-caf/sm6225/data-ipa-cfg-mgr" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git" "hardware/qcom-caf/sm6225/dataipa" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_display.git" "hardware/qcom-caf/sm6225/display" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_media.git" "hardware/qcom-caf/sm6225/media" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_audio.git" "hardware/qcom-caf/sm6225/audio/primary-hal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/device_qcom_sepolicy_vndr.git" "device/qcom/sepolicy_vndr/sm6225" "lineage-23.2-caf-sm6225"
print_header "HALs cloned"

# Clone Via browser to packages/apps/Via
echo -e "${CYAN}Cloning Via browser...${RESET}"
mkdir -p packages/apps/Via
git clone --depth 1 https://github.com/AviumUI/android_packages_apps_Via.git packages/apps/Via
rm -rf packages/apps/Via/.git
print_header "Via browser cloned to packages/apps/Via"

# Cleanup vendor
rm -rf vendor/lineage
print_header "Vendor cleanup completed"

# Clone modified vendor
clone_repo "https://github.com/sapphire-sm6225/android_vendor_lineage.git" "lineage-23.2" "vendor/lineage"

# Add Via browser to device.mk (Melhoria 7)
add_to_device_mk "Via"

# Clone AuroraStore prebuilt to vendor/aurora
echo -e "${CYAN}Cloning AuroraStore prebuilt...${RESET}"
rm -rf vendor/aurora
git clone --depth 1 -b 12L https://github.com/MSe1969/AuroraStore-prebuilt.git vendor/aurora
rm -rf vendor/aurora/.git
print_header "AuroraStore prebuilt cloned to vendor/aurora"

# Add AuroraStore to device.mk (Melhoria 7)
add_to_device_mk "AuroraStore"
add_to_device_mk "AuroraServices"

# ================================
# Comment Gapps line in lineage_sapphire.mk
LINEAGE_SAPPHIRE_MK="device/xiaomi/sapphire/lineage_sapphire.mk"
if [ -f "$LINEAGE_SAPPHIRE_MK" ]; then
    sed -i 's/^-include vendor\/gapps\/arm64\/arm64-vendor.mk/#-include vendor\/gapps\/arm64\/arm64-vendor.mk/' "$LINEAGE_SAPPHIRE_MK"
    print_header "Gapps line commented in lineage_sapphire.mk"
else
    echo -e "${YELLOW}lineage_sapphire.mk not found, skipping Gapps comment${RESET}"
fi

# ================================
# Patch Signature Spoofing (Melhoria 5)
patch_signature_spoofing

# ================================
# Add MicroG suffix to version.mk (Melhoria 9)
patch_version_mk

# Setup build environment
source build/envsetup.sh
export BUILD_USERNAME=WhoFoss
export BUILD_HOSTNAME=los23
export SKIP_ABI_CHECKS=true
mkdir -p out/target/product/sapphire/obj/KERNEL_OBJ/usr

# ================================
# Build ROM
# ================================
# export WITH_MICROG=true
# export WITH_GMS=true
brunch sapphire user || error_exit "Brunch failed"
print_header "Build process completed successfully!"
