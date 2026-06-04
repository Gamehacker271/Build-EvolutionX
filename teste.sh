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
# Terminal Detection
# ================================
if [ -t 1 ] && [ -t 0 ]; then
    IS_TTY=true
    TTY_WIDTH=$(tput cols 2>/dev/null || echo 80)
else
    IS_TTY=false
    TTY_WIDTH=80
fi

# ================================
# Visual Output (Universal)
# ================================
center_line() {
    local msg="$1"
    local color="$2"
    local char="${3:--}"
    
    if [ "$IS_TTY" = true ]; then
        local msg_len=${#msg}
        local total_len=$((msg_len + 4))
        local pad=$(( (TTY_WIDTH - total_len) / 2 ))
        [ "$pad" -lt 0 ] && pad=1
        local line=$(printf '%*s' "$pad" '' | tr ' ' "$char")
        printf "${color}${line}[ %s ]${line}${RESET}\n" "$msg"
    else
        printf "\n${color}═══ %s ═══${RESET}\n\n" "$msg"
    fi
}

print_header() { 
    center_line "$1" "\033[1;32m" "="
    if [ "$IS_TTY" = true ]; then
        sleep 1
        clear
    fi
}

print_warning() { center_line "$1" "\033[1;33m" "!"; }
print_error() { center_line "$1" "\033[1;31m" "="; }
print_info() { center_line "$1" "\033[1;36m" "-"; }

# ================================
# Helper Functions
# ================================
error_exit() {
    print_error "$1"
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "$1 is required but not installed"
}

cleanup_repos() {
    print_info "Performing cleanup..."
    rm -rf .repo/local_manifests/ 2>/dev/null
    rm -rf hardware/qcom-caf/common 2>/dev/null
    rm -rf packages/apps/ThemePicker 2>/dev/null
    rm -rf vendor/qcom/opensource/healthd-ext 2>/dev/null
    rm -rf vendor/lineage 2>/dev/null
    print_header "Cleanup completed"
}

clone_repo() {
    local repo_url=$1
    local branch=$2
    local dest=$3
    
    print_info "Cloning $dest..."
    if [ -d "$dest" ]; then
        print_warning "$dest already exists, removing..."
        rm -rf "$dest"
    fi
    git clone --depth 1 -b "$branch" "$repo_url" "$dest" || error_exit "Failed to clone $dest"
    print_header "$dest clone success"
}

clone_hal() {
    local url=$1
    local path=$2
    local branch=$3
    
    print_info "Cloning HAL: $path"
    rm -rf "$path"
    git clone --depth 1 -b "$branch" "$url" "$path" || error_exit "Failed to clone HAL $path"
}

# ================================
# Pre-flight Checks
# ================================
print_info "Running pre-flight checks..."

# Check required commands
for cmd in git repo wget python3; do
    check_command "$cmd"
done

# Check disk space (minimum 200GB)
if [ "$IS_TTY" = true ]; then
    available_gb=$(df -BG . 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ -n "$available_gb" ] && [ "$available_gb" -lt 200 ]; then
        print_warning "Only ${available_gb}GB available. 200GB+ recommended."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
fi

print_header "Pre-flight checks passed"

# ================================
# Check/Create LineageOS-MicroG directory
# ================================
LINEAGE_DIR="LineageOS-MicroG"

if [ "$(basename "$PWD")" != "$LINEAGE_DIR" ]; then
    print_info "Not in $LINEAGE_DIR directory. Changing..."
    
    if [ ! -d "$HOME/$LINEAGE_DIR" ]; then
        print_warning "Creating $HOME/$LINEAGE_DIR..."
        mkdir -p "$HOME/$LINEAGE_DIR" || error_exit "Failed to create $HOME/$LINEAGE_DIR"
    fi
    
    cd "$HOME/$LINEAGE_DIR" || error_exit "Failed to cd to $HOME/$LINEAGE_DIR"
    print_header "Working directory: $PWD"
else
    print_header "Already in $LINEAGE_DIR: $PWD"
fi

# ================================
# Main Build Script
# ================================
print_info "Starting LOS 23.2 build script for sapphire..."
print_info "Build started at: $(date '+%Y-%m-%d %H:%M:%S')"

# Cleanup
cleanup_repos

# Initialize LOS repo
print_info "Initializing LineageOS repository..."
if [ -d ".repo" ]; then
    print_warning "Existing .repo found, removing..."
    rm -rf .repo
fi
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs || error_exit "Repo init failed"
print_header "Repo init success"

# Clone local manifests
clone_repo "https://github.com/saroj-nokia/local_manifests_sapphire" "sapphire16" ".repo/local_manifests"

# Create MicroG manifest
print_info "Creating MicroG manifest..."
cat > .repo/local_manifests/microg.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <remote name="lineageos4microg" fetch="https://github.com/lineageos4microg/" />
    <project path="vendor/partner_gms" name="android_vendor_partner_gms" remote="lineageos4microg" revision="master" />
</manifest>
EOF
print_header "MicroG manifest created"

# Sync MicroG vendor
print_info "Syncing MicroG vendor..."
repo sync vendor/partner_gms || error_exit "Failed to sync MicroG vendor"
print_header "MicroG vendor synced"

# Full repo sync
print_info "Starting full repository sync..."
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j14 || error_exit "Repo sync failed"
print_header "Repo sync success"

# Clone HALs
print_info "Cloning HALs for SM6225..."
clone_hal "https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git" "hardware/qcom-caf/common" "lineage-23.2"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git" "hardware/qcom-caf/sm6225/audio/agm" "lineage-22.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_arpal-lx.git" "hardware/qcom-caf/sm6225/audio/pal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git" "hardware/qcom-caf/sm6225/data-ipa-cfg-mgr" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git" "hardware/qcom-caf/sm6225/dataipa" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_display.git" "hardware/qcom-caf/sm6225/display" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_media.git" "hardware/qcom-caf/sm6225/media" "lineage-23.2-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/hardware_qcom_audio.git" "hardware/qcom-caf/sm6225/audio/primary-hal" "lineage-22.0-caf-sm6225"
clone_hal "https://github.com/sapphire-sm6225/device_qcom_sepolicy_vndr.git" "device/qcom/sepolicy_vndr/sm6225" "lineage-23.2-caf-sm6225"
print_header "All HALs cloned successfully"

# Clone Via browser
print_info "Cloning Via browser..."
mkdir -p packages/apps/Via
git clone --depth 1 https://github.com/WhoFoss/android_packages_apps_Via.git packages/apps/Via || print_warning "Failed to clone Via browser"
rm -rf packages/apps/Via/.git 2>/dev/null
print_header "Via browser cloned"

# Cleanup vendor
print_info "Cleaning vendor directory..."
rm -rf vendor/lineage
print_header "Vendor cleanup completed"

# Clone modified vendor
clone_repo "https://github.com/sapphire-sm6225/android_vendor_lineage.git" "lineage-23.2" "vendor/lineage"

# Add Via browser to device.mk
DEVICE_MK="device/xiaomi/sapphire/device.mk"
if [ -f "$DEVICE_MK" ]; then
    if ! grep -q "Via" "$DEVICE_MK"; then
        echo "PRODUCT_PACKAGES += Via" >> "$DEVICE_MK"
        print_header "Via added to device.mk"
    else
        print_warning "Via already in device.mk"
    fi
else
    print_warning "device.mk not found at $DEVICE_MK, skipping Via addition"
fi

# Clone AuroraStore prebuilt
print_info "Cloning AuroraStore prebuilt..."
rm -rf vendor/aurora
git clone --depth 1 -b 12L https://github.com/MSe1969/AuroraStore-prebuilt.git vendor/aurora || print_warning "Failed to clone AuroraStore"
rm -rf vendor/aurora/.git 2>/dev/null
print_header "AuroraStore prebuilt cloned"

# Add AuroraStore to device.mk
if [ -f "$DEVICE_MK" ]; then
    if ! grep -q "AuroraStore" "$DEVICE_MK"; then
        cat >> "$DEVICE_MK" << 'EOF'

# AuroraStore
PRODUCT_PACKAGES += AuroraStore AuroraServices
EOF
        print_header "AuroraStore added to device.mk"
    else
        print_warning "AuroraStore already exists in device.mk"
    fi
fi

# Comment Gapps line in lineage_sapphire.mk
LINEAGE_MK="device/xiaomi/sapphire/lineage_sapphire.mk"
if [ -f "$LINEAGE_MK" ]; then
    if grep -q '^-include vendor/gapps/arm64/arm64-vendor.mk' "$LINEAGE_MK"; then
        sed -i 's|^-include vendor/gapps/arm64/arm64-vendor.mk|#-include vendor/gapps/arm64/arm64-vendor.mk|' "$LINEAGE_MK"
        print_header "Gapps line commented in lineage_sapphire.mk"
    else
        print_warning "Gapps line not found or already commented"
    fi
else
    print_warning "lineage_sapphire.mk not found, skipping Gapps comment"
fi

# Patch Signature Spoofing
print_info "Patching Signature Spoofing..."
COMPUTER_ENGINE="frameworks/base/services/core/java/com/android/server/pm/ComputerEngine.java"
if [ -f "$COMPUTER_ENGINE" ]; then
    if grep -q 'if (!isDebuggable())' "$COMPUTER_ENGINE"; then
        # Create backup
        cp "$COMPUTER_ENGINE" "${COMPUTER_ENGINE}.backup"
        # Apply patch
        sed -i '/if (!isDebuggable()) {/{N;N;d}' "$COMPUTER_ENGINE"
        print_header "Signature Spoofing patch applied"
    else
        print_warning "Signature Spoofing: already patched or pattern not found"
    fi
else
    print_warning "ComputerEngine.java not found, skipping spoofing patch"
fi

# Add MicroG suffix to version.mk
print_info "Adding MicroG suffix to version.mk..."
VERSION_MK="vendor/lineage/config/version.mk"
if [ -f "$VERSION_MK" ]; then
    if ! grep -q "MICROG" "$VERSION_MK"; then
        cat >> "$VERSION_MK" << 'EOF'

# MicroG suffix
ifeq ($(WITH_GMS),true)
LINEAGE_VERSION_SUFFIX := $(LINEAGE_VERSION_SUFFIX)-MICROG
endif

# Custom build tag
ifneq ($(BUILD_TAG),)
LINEAGE_VERSION_SUFFIX := $(LINEAGE_VERSION_SUFFIX)-$(BUILD_TAG)
endif
EOF
        print_header "MicroG suffix patch applied successfully"
    else
        print_warning "MicroG suffix already exists in version.mk"
    fi
else
    print_warning "version.mk not found, skipping suffix patch"
fi

# Setup build environment
print_info "Setting up build environment..."
if [ -f "build/envsetup.sh" ]; then
    source build/envsetup.sh
    print_header "Build environment ready"
else
    error_exit "build/envsetup.sh not found. Repository may not be properly synced."
fi

# Export build variables
export BUILD_USERNAME=WhoFoss
export BUILD_HOSTNAME=los23
export SKIP_ABI_CHECKS=true

# Create kernel obj directory
mkdir -p out/target/product/sapphire/obj/KERNEL_OBJ/usr

# Install gofile upload tool (only if interactive)
if [ "$IS_TTY" = true ]; then
    print_info "Installing gofile upload tool..."
    wget -q https://raw.githubusercontent.com/kenway214/GoFile-Upload-Script/master/upload.sh -O ~/gofile 2>/dev/null && {
        chmod +x ~/gofile
        if ! grep -q "alias gofile=" ~/.bashrc 2>/dev/null; then
            echo 'alias gofile="~/gofile"' >> ~/.bashrc
        fi
        print_header "gofile installed successfully"
    } || print_warning "Failed to install gofile"
fi

# ================================
# Build ROM
# ================================
print_info "Starting build process..."
print_info "Build started at: $(date '+%Y-%m-%d %H:%M:%S')"

# Uncomment if needed
# export WITH_MICROG=true
# export WITH_GMS=true

brunch sapphire user || error_exit "Build failed"

print_header "BUILD COMPLETED SUCCESSFULLY!"
print_info "Build finished at: $(date '+%Y-%m-%d %H:%M:%S')"

# Show output directory
if [ -d "out/target/product/sapphire" ]; then
    print_info "Your ROM is in: out/target/product/sapphire/"
    ls -lh out/target/product/sapphire/*.zip 2>/dev/null || print_warning "No zip file found"
fi
