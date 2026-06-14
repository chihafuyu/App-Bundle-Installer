$ErrorActionPreference = "Stop"

# Load .NET assembly required for fast ZIP extraction and Anti ZIP-Bomb measures
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir = $PSScriptRoot
$inputDir = Join-Path $scriptDir "Input"

# Ensure input directory exists on startup
if (-not (Test-Path $inputDir)) {
    New-Item -ItemType Directory -Path $inputDir | Out-Null
}

$currentState = "Step1_Ready"
$installerSource = ""
$adbExe = "adb"

# Main Interactive State Machine
while ($true) {
    switch ($currentState) {
        
        "Step1_Ready" {
            Clear-Host
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "               APP BUNDLE INSTALLER                   " -ForegroundColor Cyan
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "[!] SECURITY WARNING: This tool bypasses APK signature" -ForegroundColor Yellow
            Write-Host "    verification. Only install bundle files from" -ForegroundColor Yellow
            Write-Host "    developers and sources you absolutely trust." -ForegroundColor Yellow
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "Drop all your bundle files (.apkm, .apks, .xapk, .zip)"
            Write-Host "into the 'Input' folder before proceeding."
            Write-Host "Folder path: $inputDir"
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host ""
            
            $response = Read-Host "Are your files ready? (Y to continue, N to exit)"
            if ($response -match '^[Yy]$') { 
                $currentState = "Step2_Source" 
            } elseif ($response -match '^[Nn]$') { 
                exit 
            }
        }
        
        "Step2_Source" {
            Clear-Host
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "             SELECT FAKE INSTALLER SOURCE             " -ForegroundColor Cyan
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "[1] Google Play Store (com.android.vending)"
            Write-Host "[2] Built-in Package Installer (com.google.android.packageinstaller)"
            Write-Host "[3] Samsung Galaxy Store (com.sec.android.app.samsungapps)"
            Write-Host "[4] Huawei AppGallery (com.huawei.appmarket)"
            Write-Host "[5] OPPO/Realme/OnePlus App Market (com.oppo.market)"
            Write-Host "[6] VIVO V-Appstore (com.vivo.appstore)"
            Write-Host "[7] Xiaomi/POCO/Redmi GetApps (com.xiaomi.mipicks)"
            Write-Host "[8] Amazon AppStore (com.amazon.venezia)"
            Write-Host "[B] Back to Previous Menu"
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host ""
            
            $sourceChoice = Read-Host "Select your installer source (1-8 or B)"
            
            switch -Regex ($sourceChoice) {
                '^1$' { $installerSource = "com.android.vending"; $currentState = "Step3_Execute" }
                '^2$' { $installerSource = "com.google.android.packageinstaller"; $currentState = "Step3_Execute" }
                '^3$' { $installerSource = "com.sec.android.app.samsungapps"; $currentState = "Step3_Execute" }
                '^4$' { $installerSource = "com.huawei.appmarket"; $currentState = "Step3_Execute" }
                '^5$' { $installerSource = "com.oppo.market"; $currentState = "Step3_Execute" }
                '^6$' { $installerSource = "com.vivo.appstore"; $currentState = "Step3_Execute" }
                '^7$' { $installerSource = "com.xiaomi.mipicks"; $currentState = "Step3_Execute" }
                '^8$' { $installerSource = "com.amazon.venezia"; $currentState = "Step3_Execute" }
                '^[Bb]$' { $currentState = "Step1_Ready" }
                default {
                    Write-Host "`n[!] Invalid choice. Please enter a number between 1-8 or B." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        }
        
        "Step3_Execute" {
            Clear-Host
            Write-Host "[1] Checking ADB availability..." -ForegroundColor Cyan

            # Check for native ADB or local appdata without polluting system PATH
            if (Get-Command "adb.exe" -ErrorAction SilentlyContinue) {
                $adbExe = "adb.exe"
            } else {
                $localAdbPath = Join-Path $env:LOCALAPPDATA "Android\platform-tools\adb.exe"
                if (Test-Path $localAdbPath) {
                    $adbExe = $localAdbPath
                } else {
                    Write-Host "[WARNING] adb.exe is not found in your system." -ForegroundColor Yellow
                    $dlPrompt = Read-Host "Download Android Platform Tools automatically? (Y to download, N to exit, B to go back)"
                    
                    if ($dlPrompt -match '^[Bb]$') {
                        $currentState = "Step2_Source"
                        continue
                    } elseif ($dlPrompt -match '^[Yy]$') {
                        Write-Host "Downloading Android Platform Tools. Hang tight..." -ForegroundColor Cyan
                        try {
                            $installDir = Join-Path $env:LOCALAPPDATA "Android"
                            $zipPath = Join-Path $env:TEMP "platform-tools.zip"
                            $url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
                            
                            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
                            
                            if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
                            
                            Write-Host "Extracting files..." -ForegroundColor Cyan
                            Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
                            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                            
                            $adbExe = Join-Path $installDir "platform-tools\adb.exe"
                            Write-Host "[OK] ADB installed successfully!" -ForegroundColor Green
                        } catch {
                            Write-Host "[ERROR] Failed to download or install ADB: $($_.Exception.Message)" -ForegroundColor Red
                            Read-Host "Press Enter to exit"
                            exit
                        }
                    } else {
                        exit
                    }
                }
            }

            # Fetch connected devices
            $devicesRaw = & $adbExe devices
            $connectedDevices = @($devicesRaw -split "`r?`n" | Where-Object { $_ -match "`tdevice$" })

            if ($connectedDevices.Count -eq 0) {
                Write-Host "[ERROR] No Android devices detected. Ensure USB Debugging is on." -ForegroundColor Red
                Start-Process -FilePath $adbExe -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                
                $retryPrompt = Read-Host "Press B to go back to source menu, or Enter to exit"
                if ($retryPrompt -match '^[Bb]$') {
                    $currentState = "Step2_Source"
                    continue
                }
                exit
            } elseif ($connectedDevices.Count -gt 1) {
                # Handle multi-device selection gracefully
                Write-Host "Multiple devices detected:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $connectedDevices.Count; $i++) {
                    $devName = ($connectedDevices[$i] -split "`t")[0].Trim()
                    Write-Host "[$($i + 1)] $devName"
                }
                $devChoice = Read-Host "Select target device (1-$($connectedDevices.Count))"
                
                # Prevent ugly casting exceptions if user types letters
                if ($devChoice -notmatch '^\d+$') {
                    Write-Host "`n[ERROR] Invalid input. Please enter a valid number." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                    continue
                }
                
                $idx = [int]$devChoice - 1
                
                if ($idx -ge 0 -and $idx -lt $connectedDevices.Count) {
                    $targetDevice = ($connectedDevices[$idx] -split "`t")[0].Trim()
                } else {
                    Write-Host "`n[ERROR] Invalid device selection. Out of range." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                    continue
                }
            } else {
                $targetDevice = ($connectedDevices[0] -split "`t")[0].Trim()
            }

            Write-Host "[OK] Device selected: $targetDevice" -ForegroundColor Green
            Write-Host "`n[2] Scanning Input folder..." -ForegroundColor Cyan

            $bundleFiles = Get-ChildItem -Path $inputDir -Include *.apkm,*.apks,*.xapk,*.zip -Recurse

            if ($bundleFiles.Count -eq 0) {
                Write-Host "[INFO] No bundle files found in the Input folder." -ForegroundColor Yellow
                Start-Process -FilePath $adbExe -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                
                $emptyPrompt = Read-Host "Press B to go back or Enter to exit"
                if ($emptyPrompt -match '^[Bb]$') {
                    $currentState = "Step2_Source"
                    continue
                }
                exit
            }

            # UX protection against accidental massive folder drops
            if ($bundleFiles.Count -gt 50) {
                Write-Host "`n[WARNING] You have placed a massive amount of files ($($bundleFiles.Count)) in the Input folder." -ForegroundColor Yellow
                $massPrompt = Read-Host "This might take a very long time. Are you sure you want to proceed? (Y/N)"
                if ($massPrompt -notmatch '^[Yy]$') {
                    Write-Host "Aborting execution." -ForegroundColor Yellow
                    Start-Process -FilePath $adbExe -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    $currentState = "Step1_Ready"
                    continue
                }
            }

            Write-Host "`nFound $($bundleFiles.Count) bundle file(s). Target Source: $installerSource`n" -ForegroundColor Green

            foreach ($bundle in $bundleFiles) {
                Write-Host "------------------------------------------------------"
                Write-Host "Processing: $($bundle.Name)" -ForegroundColor Magenta
                
                $zip = $null
                # Memory-safe ZIP Bomb Validation
                try {
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($bundle.FullName)
                    
                    # Defend against CPU exhaustion from millions of dummy entries
                    if ($zip.Entries.Count -gt 10000) {
                        Write-Host "  -> [WARNING] Archive contains too many entries ($($zip.Entries.Count)). Skipping to prevent CPU exhaustion." -ForegroundColor Yellow
                        continue
                    }

                    $totalUncompressedSize = 0
                    foreach ($entry in $zip.Entries) {
                        $totalUncompressedSize += $entry.Length
                    }

                    $uncompressedMB = [math]::Round($totalUncompressedSize / 1MB, 2)
                    if ($uncompressedMB -gt 3500) { # 3.5GB uncompressed limit
                        Write-Host "  -> [WARNING] Uncompressed size is dangerously large ($uncompressedMB MB). Skipping to prevent ZIP bomb/resource exhaustion." -ForegroundColor Yellow
                        continue
                    }
                } catch {
                    Write-Host "  -> [ERROR] Failed to read archive structure. The file might be corrupted." -ForegroundColor Red
                    continue
                } finally {
                    # Release file handle to prevent OS file locks
                    if ($null -ne $zip) { $zip.Dispose() }
                }
                
                $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "abi_temp_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                
                try {
                    $tempZip = Join-Path $tempDir "temp_bundle.zip"
                    Copy-Item -Path $bundle.FullName -Destination $tempZip -Force
                    
                    Write-Host "  -> Extracting bundle..."
                    # Use native .NET for faster extraction without console text bleeding
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempDir)
                    
                    # Enforce valid bundle structure
                    $baseApkCheck = Get-ChildItem -Path $tempDir -Filter 'base.apk' -Recurse
                    if (-not $baseApkCheck) {
                        Write-Host "  -> [ERROR] 'base.apk' is missing from the bundle. Invalid archive structure. Skipping..." -ForegroundColor Red
                        continue
                    }

                    $apkList = Get-ChildItem -Path $tempDir -Filter *.apk -Recurse
                    
                    if ($apkList.Count -eq 0) {
                        Write-Host "  -> [ERROR] No .apk files found inside this bundle. Skipping..." -ForegroundColor Red
                        continue
                    }

                    # Prevent CLI command string overflow
                    if ($apkList.Count -gt 150) {
                        Write-Host "  -> [ERROR] APK fragment count exceeds safe limit ($($apkList.Count) files). Skipping to prevent command-line overflow." -ForegroundColor Red
                        continue
                    }

                    Write-Host "  -> Found $($apkList.Count) APK fragments. Starting installation..."
                    
                    # Build ADB arguments array with fake installer source
                    $adbArgs = @("-s", $targetDevice, "install-multiple", "-i", $installerSource)
                    foreach ($apk in $apkList) {
                        $adbArgs += $apk.FullName
                    }
                    
                    # Use call operator (&) to capture native ADB stdout/stderr
                    $installOutput = & $adbExe $adbArgs 2>&1
                    
                    if ($LASTEXITCODE -eq 0 -and $installOutput -match "Success") {
                        Write-Host "  -> [OK] App installed successfully." -ForegroundColor Green
                    } else {
                        Write-Host "  -> [ERROR] Failed to install app. ADB Output:" -ForegroundColor Red
                        Write-Host "     $installOutput" -ForegroundColor DarkGray
                    }
                    
                    # Handle OBB data mapping automatically
                    $obbFolder = Join-Path $tempDir "Android\obb"
                    if (Test-Path $obbFolder) {
                        $obbItems = Get-ChildItem -Path $obbFolder -Directory
                        foreach ($obbAppFolder in $obbItems) {
                            Write-Host "  -> Found OBB data. Pushing $($obbAppFolder.Name) to device..."
                            $pushArgs = @("-s", $targetDevice, "push", $obbAppFolder.FullName, "/sdcard/Android/obb/")
                            
                            $pushOutput = & $adbExe $pushArgs 2>&1
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "  -> [OK] OBB transfer complete." -ForegroundColor Green
                            } else {
                                Write-Host "  -> [ERROR] OBB transfer failed: $pushOutput" -ForegroundColor Red
                            }
                        }
                    }
                    
                } catch {
                    Write-Host "  -> [FATAL ERROR] An error occurred while processing $($bundle.Name): $_" -ForegroundColor Red
                } finally {
                    # Aggressive cleanup prevents filling up the system drive
                    if (Test-Path $tempDir) {
                        Write-Host "  -> Cleaning up temporary files..."
                        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            Write-Host "------------------------------------------------------"
            Write-Host "All tasks completed!" -ForegroundColor Cyan

            Write-Host "Releasing ADB background process..." -ForegroundColor DarkGray
            Start-Process -FilePath $adbExe -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

            $endPrompt = Read-Host "Press B to return to Main Menu, or Enter to exit"
            if ($endPrompt -match '^[Bb]$') {
                $currentState = "Step1_Ready"
                continue
            }
            exit
        }
    }
}