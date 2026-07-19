# Build EvolutionX for Sapphire (Redmi Note 13 4G)

This repository contains an automated build script to compile **EvolutionX 10 (Android 15 / vic)** for the **sapphire** device. 

The script is designed to be non-destructive (it does not delete your other workspaces) and will execute entirely within your current working directory. It also automatically integrates **ViPER4AndroidFX** at the hardware/device tree level and uploads the finished build to GoFile.

## 🚀 How to Use

Since the script operates strictly in the directory where it is called, you must create a dedicated folder for your workspace before running the command.

Run the following commands in your server's terminal:

**1. Create and enter your workspace directory:**
```bash
mkdir -p ~/evox && cd ~/evox
```

**2. Execute the build script directly from GitHub:**
```bash
curl -fsSL https://raw.githubusercontent.com/Gamehacker271/Build-EvolutionX/main/EvolutionX10/evox.sh | bash
```

## ⚙️ Features
* **Safe Workspace:** Operates only in the current directory; does not touch your home `~/.repo` or wipe other existing folders.
* **Automated Sync & Build:** Initializes the EvolutionX `vic` branch, clones sapphire-specific local manifests and HALs, and builds `evolution_sapphire-userdebug`.
* **Audio Mod Integration:** Pre-integrates ViPER4AndroidFX (injects SEPolicy rules, edits `audio_effects.xml`, and disables A2DP hardware offload via `vendor.prop`).
* **Auto-Upload:** Automatically uploads the final `.zip` ROM to GoFile upon a successful build.

## ⚠️ Prerequisites
Ensure your build server is properly set up with the standard AOSP build environment and dependencies before running this script.
