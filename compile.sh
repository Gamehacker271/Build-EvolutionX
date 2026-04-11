# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Automatic cleanup
echo -e "${YELLOW}Performing cleanup...${RESET}"
rm -rf .repo/local_manifests/
rm -rf hardware/qcom-caf/common
rm -rf packages/apps/Updater
rm -rf packages/apps/ThemePicker
rm -rf packages/apps/Settings
rm -rf vendor/qcom/opensource/healthd-ext
rm -rf system/media
rm -rf hardware/interfaces
rm -rf vendor/lineage
echo -e "${GREEN}Cleanup completed.${RESET}"
echo ""
clear

# Initialize the ROM source repository
echo -e "${CYAN}Initializing repo...${RESET}"
repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs
if [ $? -ne 0 ]; then
    echo -e "${RED}Repo initialization failed. Exiting.${RESET}"
    exit 1
fi
echo -e "${GREEN}=================${RESET}"
echo -e "${GREEN}Repo init success${RESET}"
echo -e "${GREEN}=================${RESET}"
echo ""
clear

# Clone local manifests
echo -e "${CYAN}Cloning local manifests...${RESET}"
git clone https://github.com/saroj-nokia/local_manifests_sapphire --depth 1 -b sapphire15 .repo/local_manifests
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to clone local manifests. Exiting.${RESET}"
    exit 1
fi
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}Local manifest clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Create MicroG manifest
echo -e "${CYAN}Creating MicroG manifest...${RESET}"
cat > .repo/local_manifests/microg.xml << 'EOF'
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
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}MicroG manifest created${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Sync the repositories
echo -e "${CYAN}Syncing repositories...${RESET}"
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j14
if [ $? -ne 0 ]; then
    echo -e "${RED}Repo sync failed. Exiting.${RESET}"
    exit 1
fi
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}Repo sync success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Sync MicroG vendor
echo -e "${CYAN}Syncing MicroG vendor...${RESET}"
repo sync vendor/partner_gms
if [ $? -ne 0 ]; then
    echo -e "${RED}MicroG vendor sync failed. Exiting.${RESET}"
    exit 1
fi
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}MicroG vendor sync success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Automatic cleanup
echo -e "${YELLOW}Performing cleanup...${RESET}"
rm -rf packages/apps/Updater
rm -rf packages/apps/ThemePicker
rm -rf packages/apps/Settings
rm -rf system/media
rm -rf hardware/interfaces
rm -rf vendor/lineage
echo -e "${GREEN}Cleanup completed.${RESET}"
echo ""
clear

# Clone modified lineage updater repo
echo -e "${CYAN}Cloning modified Updater repo...${RESET}"
git clone https://github.com/sapphire-sm6225/android_packages_apps_Updater -b lineage-22.2 packages/apps/Updater
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}modified lineage updater repo clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Clone modified lineage ThemePicker repo
echo -e "${CYAN}Cloning modified ThemePicker repo...${RESET}"
git clone https://github.com/sapphire-sm6225/android_packages_apps_ThemePicker -b lineage-22.2 packages/apps/ThemePicker
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}modified lineage ThemePicker repo clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Clone modified lineage Settings repo
echo -e "${CYAN}Cloning modified Settings repo...${RESET}"
git clone https://github.com/sapphire-sm6225/android_packages_apps_Settings -b lineage-22.2 packages/apps/Settings
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}modified lineage Settings repo clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Clone modified system media repo
echo -e "${CYAN}Cloning modified system/media repo...${RESET}"
git clone https://github.com/sapphire-sm6225/android_system_media.git -b lineage-22.2 system/media
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}modified lineage no audio ringtone while bluetooth connect repo clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Clone modified hardware interfaces repo
echo -e "${CYAN}Cloning modified hardware/interfaces repo...${RESET}"
git clone https://github.com/sapphire-sm6225/android_hardware_interfaces.git -b lineage-22.2 hardware/interfaces
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}modified lineage no audio ringtone while bluetooth connect repo clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Clone modified lineage vendor repo
echo -e "${CYAN}Cloning modified vendor/lineage repo...${RESET}"
git clone https://github.com/sapphire-sm6225/android_vendor_lineage.git -b lineage-22.2 vendor/lineage
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}modified lineage vendor repo clone success${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Clone HALs for SM6225
echo -e "${CYAN}Cloning HALs for SM6225...${RESET}"
rm -rf hardware/qcom-caf/common
git clone --depth 1 -b lineage-22.2 https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git hardware/qcom-caf/common

rm -rf hardware/qcom-caf/sm6225/audio/agm
git clone --depth 1 -b lineage-22.2-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_agm.git hardware/qcom-caf/sm6225/audio/agm

rm -rf hardware/qcom-caf/sm6225/audio/pal
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_arpal-lx.git hardware/qcom-caf/sm6225/audio/pal

rm -rf hardware/qcom-caf/sm6225/data-ipa-cfg-mgr
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_data-ipa-cfg-mgr.git hardware/qcom-caf/sm6225/data-ipa-cfg-mgr

rm -rf hardware/qcom-caf/sm6225/dataipa
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/vendor_qcom_opensource_dataipa.git hardware/qcom-caf/sm6225/dataipa

rm -rf hardware/qcom-caf/sm6225/display
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/hardware_qcom_display.git hardware/qcom-caf/sm6225/display

rm -rf hardware/qcom-caf/sm6225/media
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/hardware_qcom_media.git hardware/qcom-caf/sm6225/media

rm -rf hardware/qcom-caf/sm6225/audio/primary-hal
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/hardware_qcom_audio.git hardware/qcom-caf/sm6225/audio/primary-hal

rm -rf device/qcom/sepolicy_vndr/sm6225
git clone --depth 1 -b lineage-22.0-caf-sm6225 https://github.com/sapphire-sm6225/device_qcom_sepolicy_vndr.git device/qcom/sepolicy_vndr/sm6225

rm -rf vendor/qcom/opensource/healthd-ext
git clone --depth 1 -b lineage-22.2 https://github.com/sapphire-sm6225/android_vendor_qcom_opensource_healthd-ext.git vendor/qcom/opensource/healthd-ext
echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}Cloning HALs completed${RESET}"
echo -e "${GREEN}============================${RESET}"
echo ""
clear

# Patch ComputerEngine.java to enable Signature Spoofing on user builds
echo -e "${CYAN}Applying Signature Spoofing patch...${RESET}"
COMPUTER_ENGINE="frameworks/base/services/core/java/com/android/server/pm/ComputerEngine.java"

if grep -q "if (!isDebuggable())" "$COMPUTER_ENGINE"; then
    sed -i '/if (!isDebuggable()) {/{N;N;d}' "$COMPUTER_ENGINE"
    echo -e "${GREEN}============================${RESET}"
    echo -e "${GREEN}Signature Spoofing patch applied${RESET}"
    echo -e "${GREEN}============================${RESET}"
else
    echo -e "${YELLOW}Signature Spoofing patch: block not found, may already be patched or line changed.${RESET}"
fi
echo ""
clear

# Build environment setup
echo -e "${CYAN}Setting up build environment...${RESET}"
source build/envsetup.sh
export BUILD_USERNAME=sarojtaj77
export BUILD_HOSTNAME=T800-machine
export WITH_GMS=true

# Build the ROM
echo -e "${CYAN}Running lunch...${RESET}"
lunch lineage_sapphire-bp1a-user
if [ $? -ne 0 ]; then
    echo -e "${RED}Lunch failed. Exiting.${RESET}"
    exit 1
fi
clear

echo -e "${CYAN}Running installclean...${RESET}"
make installclean
if [ $? -ne 0 ]; then
    echo -e "${RED}Installclean failed. Exiting.${RESET}"
    exit 1
fi
clear

echo -e "${CYAN}Building ROM...${RESET}"
mka bacon
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed. Exiting.${RESET}"
    exit 1
fi

echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}Build process completed successfully!${RESET}"
echo -e "${GREEN}============================${RESET}"
clear

# Upload ROM zip file to GoFile
ROM_DIR="out/target/product/sapphire/"
ROM_NAME=$(ls $ROM_DIR | grep "lineage-22.2-.*-UNOFFICIAL-sapphire.zip$" | tail -n 1)

if [ -n "$ROM_NAME" ]; then
    ROM_PATH="$ROM_DIR$ROM_NAME"
    echo -e "${CYAN}Uploading ROM to GoFile...${RESET}"
    curl -s https://raw.githubusercontent.com/saroj-nokia/GoFile-Upload/refs/heads/master/upload.sh | bash -s -- "$ROM_PATH"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ROM uploaded successfully to GoFile!${RESET}"
    else
        echo -e "${RED}Failed to upload ROM to GoFile.${RESET}"
    fi
else
    echo -e "${YELLOW}ROM file not found. Upload skipped.${RESET}"
fi

echo -e "${GREEN}============================${RESET}"
echo -e "${GREEN}ROM upload completed${RESET}"
echo -e "${GREEN}============================${RESET}"
