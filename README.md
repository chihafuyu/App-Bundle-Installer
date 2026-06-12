# App Bundle Installer (CLI)

A simple, interactive PowerShell script designed to automate the installation of Android App Bundles (`.apks`, `.apkm`, `.xapk`, `.zip`) directly from your PC to your Android device via ADB. 

## ✨ Features

* **Seamless Split APK Installation:** Automatically extracts bundles and streams all APK fragments (base, dpi, language, architecture) in one go using `adb install-multiple`.
* **Fake Installer Source Spoofing:** Tricks the Android Package Manager into thinking the app was downloaded directly from the Google Play Store (`com.android.vending`) or the Built-in Package Installer.
* **Smart OBB Handling:** Automatically detects and pushes OBB data to `/sdcard/Android/obb/` if it's included in the bundle (typically found in `.xapk` files).
* **Auto ADB Setup:** Don't have ADB installed? The script will detect it and offer to automatically download and configure Android Platform Tools to your Windows system PATH.
* **Interactive CLI:** A clean, text-based UI with a Global Back feature (just hit `B` to jump back to the previous menu at any time).
* **Zero Memory Leaks:** Aggressive cleanup of temp files and background processes (ADB Daemon). No zombie processes left eating up your RAM after you close the script.

## 🚀 How to Use

1. **Clone or download** this repository to your PC.
2. Run `App-Bundle-Installer.ps1` for the first time. It will automatically create an `Input` folder in the same directory.
3. Drop all your bundle files (`.apks`, `.apkm`, `.xapk`, or `.zip`) into the `Input` folder.
4. Make sure your Android device is connected to your PC and **USB Debugging** is enabled.
5. Follow the interactive on-screen prompts:
   - Hit `Y` to start.
   - Choose your preferred Fake Installer Source.
   - Sit back and let the script do the heavy lifting.

## 🛠️ System Requirements

* Windows 10 / 11
* PowerShell 5.1 or newer (pre-installed on Windows)
* An Android device with Developer Options and USB Debugging enabled.

## 💡 Notes

* **Auto-Cleanup:** This script respects your storage space. All temporary extraction folders are instantly wiped the moment an installation succeeds or fails.
* **Execution Policy:** If Windows PowerShell blocks the script from running due to security policies, open PowerShell as Administrator and run this command once:
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
  
## 📄 License

This project is created by **chihafuyu** and is open-sourced under the **[MIT License](https://opensource.org/licenses/mit)**.

**Copyright (c) 2026 chihafuyu**

Basically: you are free to use, modify, and distribute this tool for any purpose, as long as you keep the original copyright notice above. It is provided _"as is"_, without warranty of any kind. Use it at your own risk!