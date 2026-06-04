#!/bin/bash
set -euo pipefail

# ================================
# Colors
# ================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RESET='\033[0m'

# ================================
# Configurações Centralizadas
# ================================
readonly DEVICE_CODENAME="sapphire"
readonly ANDROID_VERSION="lineage-23.2"
readonly LOS_BRANCH="lineage-23.2"
readonly BUILD_DIR_NAME="LineageOS-MicroG"
readonly BASE_BUILD_DIR="${HOME}/${BUILD_DIR_NAME}"
readonly DEVICE_PATH="device/xiaomi/${DEVICE_CODENAME}"
readonly DEVICE_MK="${DEVICE_PATH}/device.mk"
readonly LINEAGE_SAPPHIRE_MK="${DEVICE_PATH}/lineage_${DEVICE_CODENAME}.mk"
readonly OUT_DIR="out/target/product/${DEVICE_CODENAME}"
readonly COMPUTER_ENGINE="frameworks/base/services/core/java/com/android/server/pm/ComputerEngine.java"

# Build configuration
readonly BUILD_CONFIG=(
    "BUILD_USERNAME=WhoFoss"
    "BUILD_HOSTNAME=los23"
    "SKIP_ABI_CHECKS=true"
    "WITH_MICROG=true"
    "WITH_GMS=true"
)

# HALs repositories
declare -A HALS=(
    ["hardware/qcom-caf/common"]="https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git lineage-23.2"
    ["hardware/qcom-caf/sm6225/audio/agm"]="https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git lineage-22.2-caf-sm6225"
    ["hardware/qcom-caf/sm6225/audio/pal"]="https://github.com/sapphire-sm6225/vendor_qcom_opensource_arpal-lx.git lineage-22.0-caf-sm6225"
    ["hardware/qcom-caf/sm6225/data-ipa-cfg-mgr"]="https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git lineage-23.2-caf-sm6225"
    ["hardware/qcom-caf/sm6225/dataipa"]="https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git lineage-23.2-caf-sm6225"
    ["hardware/qcom-caf/sm6225/display"]="https://github.com/sapphire-sm6225/hardware_qcom_display.git lineage-22.0-caf-sm6225"
    ["hardware/qcom-caf/sm6225/media"]="https://github.com/sapphire-sm6225/hardware_qcom_media.git lineage-23.2-caf-sm6225"
    ["hardware/qcom-caf/sm6225/audio/primary-hal"]="https://github.com/sapphire-sm6225/hardware_qcom_audio.git lineage-22.0-caf-sm6225"
    ["device/qcom/sepolicy_vndr/sm6225"]="https://github.com/sapphire-sm6225/device_qcom_sepolicy_vndr.git lineage-23.2-caf-sm6225"
)

# ================================
# Logging Functions
# ================================
log_info() { 
    echo -e "${CYAN}[INFO]${RESET} $1"
}

log_success() { 
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() { 
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() { 
    echo -e "${RED}[ERROR]${RESET} $1"
}

# ================================
# Helper Functions
# ================================
error_exit() {
    local exit_code=$?
    local message="$1"
    
    log_error "$message"
    echo -e "${RED}Exit code: ${exit_code}${RESET}" >&2
    
    # Log do erro
    echo "[$(date)] ERROR: $message" >> "build_errors.log"
    
    exit "${exit_code}"
}

# Trap para sinais
trap 'error_exit "Interrupted by user"' INT TERM

print_banner() {
    cat << "EOF"
+--------------------------------------------------+
|     LineageOS 23.2 MicroG Builder               |
|     Device: Nokia Sapphire (SM6225)             |
+--------------------------------------------------+
EOF
}

print_header() {
    local msg="$1"
    local len=${#msg}
    local border=$(printf '%*s' "$((len + 4))" | tr ' ' '-')
    
    echo -e "\n${GREEN}+${border}+${RESET}"
    echo -e "${GREEN}|  ${msg}  |${RESET}"
    echo -e "${GREEN}+${border}+${RESET}\n"
}

print_separator() {
    echo -e "${CYAN}--------------------------------------------------${RESET}"
}

# ================================
# Core Functions
# ================================
cleanup_repos() {
    log_info "Performing cleanup..."
    rm -rf .repo/local_manifests/
    rm -rf hardware/qcom-caf/common
    rm -rf packages/apps/ThemePicker
    rm -rf vendor/qcom/opensource/healthd-ext
    rm -rf vendor/lineage
    print_header "Cleanup completed"
    sleep 0.5
    clear
}

clone_repo() {
    local repo_url=$1
    local branch=$2
    local dest=$3
    
    log_info "Cloning ${dest}..."
    
    set +e
    git clone --depth 1 -b "$branch" "$repo_url" "$dest"
    local result=$?
    set -e
    
    if [ $result -ne 0 ]; then
        error_exit "Failed to clone ${dest}"
    fi
    
    print_header "${dest} clone success"
    sleep 0.5
    clear
}

clone_hal() {
    local url=$1
    local path=$2
    local branch=$3
    
    rm -rf "$path"
    
    set +e
    git clone --depth 1 -b "$branch" "$url" "$path"
    local result=$?
    set -e
    
    if [ $result -ne 0 ]; then
        error_exit "Failed to clone HAL ${path}"
    fi
}

clone_all_hals() {
    log_info "Cloning HALs for SM6225..."
    
    for path in "${!HALS[@]}"; do
        local url_branch="${HALS[$path]}"
        local url="${url_branch% *}"
        local branch="${url_branch#* }"
        clone_hal "$url" "$path" "$branch"
    done
    
    print_header "HALs cloned"
}

enter_build_directory() {
    if [ "$(basename "$PWD")" != "$BUILD_DIR_NAME" ]; then
        log_info "Not in ${BUILD_DIR_NAME} directory. Checking/Creating..."
        
        if [ -d "$BASE_BUILD_DIR" ]; then
            cd "$BASE_BUILD_DIR" || error_exit "Failed to cd to ${BASE_BUILD_DIR}"
            log_success "Changed to existing directory: ${PWD}"
        else
            log_info "Creating ${BASE_BUILD_DIR}..."
            mkdir -p "$BASE_BUILD_DIR" || error_exit "Failed to create ${BASE_BUILD_DIR}"
            cd "$BASE_BUILD_DIR" || error_exit "Failed to cd to ${BASE_BUILD_DIR}"
            log_success "Created and changed to: ${PWD}"
        fi
        sleep 1
    else
        log_success "Already in ${BUILD_DIR_NAME} directory: ${PWD}"
    fi
}

apply_build_config() {
    for config in "${BUILD_CONFIG[@]}"; do
        export "$config"
        log_info "Set: ${config}"
    done
}

patch_signature_spoofing() {
    if [ ! -f "$COMPUTER_ENGINE" ]; then
        log_warning "ComputerEngine.java not found, skipping signature spoofing patch"
        return 0
    fi
    
    if grep -q 'if (true) {' "$COMPUTER_ENGINE" 2>/dev/null; then
        log_warning "Signature spoofing already patched"
        return 0
    fi
    
    if grep -q 'if (!isDebuggable())' "$COMPUTER_ENGINE"; then
        sed -i '/if (!isDebuggable()) {/,/}/ {
            s/if (!isDebuggable()) {/if (true) {/
            s/return false;/return true;/
        }' "$COMPUTER_ENGINE"
        log_success "Signature spoofing patch applied"
    else
        log_warning "Signature spoofing pattern not found"
    fi
}

add_microg_suffix() {
    local version_mk="vendor/lineage/config/version.mk"
    
    if [ ! -f "$version_mk" ]; then
        log_warning "version.mk not found, skipping MicroG suffix"
        return 0
    fi
    
    # Remove existing MICROG suffix to avoid duplication
    sed -i '/-MICROG/d' "$version_mk"
    
    sed -i '/^LINEAGE_VERSION_SUFFIX := .*/a \
\
# Add MICROG to suffix if WITH_GMS is true\
ifeq ($(WITH_GMS),true)\
    LINEAGE_VERSION_SUFFIX := $(LINEAGE_VERSION_SUFFIX)-MICROG\
endif\
\
# Add custom build tag/feature to suffix if BUILD_TAG is defined\
ifneq ($(BUILD_TAG),)\
    LINEAGE_VERSION_SUFFIX := $(LINEAGE_VERSION_SUFFIX)-$(BUILD_TAG)\
endif' "$version_mk"
    
    if grep -q "MICROG" "$version_mk"; then
        log_success "MicroG suffix patch applied successfully"
    else
        log_warning "MicroG suffix patch may not have been applied"
    fi
}

add_package_to_device_mk() {
    local package=$1
    local package_extra=${2:-}
    
    if [ ! -f "$DEVICE_MK" ]; then
        log_warning "device.mk not found at ${DEVICE_MK}, skipping ${package} addition"
        return 0
    fi
    
    if ! grep -q "$package" "$DEVICE_MK"; then
        if [ -n "$package_extra" ]; then
            echo "PRODUCT_PACKAGES += $package $package_extra" >> "$DEVICE_MK"
        else
            echo "PRODUCT_PACKAGES += $package" >> "$DEVICE_MK"
        fi
        log_success "${package} added to device.mk"
    else
        log_warning "${package} already exists in device.mk"
    fi
}

comment_gapps_line() {
    if [ -f "$LINEAGE_SAPPHIRE_MK" ]; then
        sed -i 's/^-include vendor\/gapps\/arm64\/arm64-vendor.mk/#-include vendor\/gapps\/arm64\/arm64-vendor.mk/' "$LINEAGE_SAPPHIRE_MK"
        log_success "Gapps line commented in lineage_sapphire.mk"
    else
        log_warning "lineage_sapphire.mk not found, skipping Gapps comment"
    fi
}

create_microg_manifest() {
    log_info "Creating MicroG manifest..."
    
    cat > .repo/local_manifests/microg.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="lineageos4microg"
            fetch="https://github.com/lineageos4microg/" />

    <project path="vendor/partner_gms"
             name="android_vendor_partner_gms"
             remote="lineageos4microg"
             revision="master" />
</manifest>
EOF
    
    print_header "MicroG manifest created"
}

clone_via_browser() {
    log_info "Cloning Via browser..."
    mkdir -p packages/apps/Via
    
    set +e
    git clone --depth 1 https://github.com/WhoFoss/android_packages_apps_Via.git packages/apps/Via
    local result=$?
    set -e
    
    if [ $result -eq 0 ]; then
        rm -rf packages/apps/Via/.git
        log_success "Via browser cloned to packages/apps/Via"
    else
        log_warning "Failed to clone Via browser"
    fi
}

clone_aurora_store() {
    log_info "Cloning AuroraStore prebuilt..."
    rm -rf vendor/aurora
    
    set +e
    git clone --depth 1 -b 12L https://github.com/MSe1969/AuroraStore-prebuilt.git vendor/aurora
    local result=$?
    set -e
    
    if [ $result -eq 0 ]; then
        rm -rf vendor/aurora/.git
        log_success "AuroraStore prebuilt cloned to vendor/aurora"
    else
        log_warning "Failed to clone AuroraStore"
    fi
}

setup_kernel_obj_dir() {
    mkdir -p "${OUT_DIR}/obj/KERNEL_OBJ/usr"
}

print_summary() {
    echo -e "\n${CYAN}+--------------------------------------------------+${RESET}"
    echo -e "${CYAN}|              BUILD COMPLETED                     |${RESET}"
    echo -e "${CYAN}+--------------------------------------------------+${RESET}"
    echo -e "${GREEN}| ROM:      LineageOS 23.2 with MicroG            |${RESET}"
    echo -e "${GREEN}| Device:   Nokia Sapphire                        |${RESET}"
    echo -e "${GREEN}| Date:     $(date '+%Y-%m-%d %H:%M')                      |${RESET}"
    echo -e "${CYAN}+--------------------------------------------------+${RESET}"
    echo -e "${YELLOW}| Output:   ${OUT_DIR}/ |${RESET}"
    
    if [ -d "$OUT_DIR" ]; then
        local size=$(du -sh "$OUT_DIR" 2>/dev/null | cut -f1)
        echo -e "${YELLOW}| Size:     ${size}                               |${RESET}"
    fi
    
    echo -e "${CYAN}+--------------------------------------------------+${RESET}\n"
}

# ================================
# Main Function
# ================================
main() {
    print_banner
    
    # Setup
    enter_build_directory
    cleanup_repos
    
    # Initialize LOS repo
    log_info "Starting LOS 23.2 build script..."
    repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs || error_exit "Repo init failed"
    print_header "Repo init success"
    
    # Clone local manifests
    clone_repo "https://github.com/saroj-nokia/local_manifests_sapphire" "sapphire16" ".repo/local_manifests"
    
    # Create MicroG manifest
    create_microg_manifest
    
    # Sync MicroG vendor
    log_info "Syncing MicroG vendor..."
    repo sync vendor/partner_gms || error_exit "Failed to sync MicroG vendor"
    print_header "MicroG vendor synced"
    
    # Sync repo
    repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j14 || error_exit "Repo sync failed"
    print_header "Repo sync success"
    
    # Clone HALs
    clone_all_hals
    
    # Clone Via browser
    clone_via_browser
    
    # Cleanup vendor
    rm -rf vendor/lineage
    print_header "Vendor cleanup completed"
    
    # Clone modified vendor
    clone_repo "https://github.com/sapphire-sm6225/android_vendor_lineage.git" "lineage-23.2" "vendor/lineage"
    
    # Add packages to device.mk
    add_package_to_device_mk "Via"
    add_package_to_device_mk "AuroraStore" "AuroraServices"
    
    # Clone AuroraStore
    clone_aurora_store
    
    # Comment Gapps line
    comment_gapps_line
    
    # Patch Signature Spoofing
    patch_signature_spoofing
    
    # Add MicroG suffix
    add_microg_suffix
    
    # Apply build configuration
    apply_build_config
    
    # Setup build environment
    source build/envsetup.sh || error_exit "Failed to source build/envsetup.sh"
    setup_kernel_obj_dir
    
    # Build ROM
    print_separator
    log_info "Starting build..."
    print_separator
    
    brunch "${DEVICE_CODENAME}" user || error_exit "Brunch failed"
    
    # Summary
    print_summary
    log_success "Build process completed successfully!"
}

# ================================
# Script Entry Point
# ================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
