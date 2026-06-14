$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$inputDir = Join-Path $scriptDir "Input"

# Create input directory once at startup
if (-not (Test-Path $inputDir)) {
    New-Item -ItemType Directory -Path $inputDir | Out-Null
}

$currentState = "Step1_Ready"
$installerSource = ""

# Main State Machine Loop
while ($true) {
    switch ($currentState) {
        
        "Step1_Ready" {
            Clear-Host
            Write-Host "======================================================" -ForegroundColor Cyan
            Write-Host "               APP BUNDLE INSTALLER                   " -ForegroundColor Cyan
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
                    # State remains "Step2_Source", loop restarts natively
                }
            }
        }
        
        "Step3_Execute" {
            Clear-Host
            Write-Host "[1] Checking ADB availability..." -ForegroundColor Cyan

            # Check ADB in system PATH
            $adbExists = Get-Command "adb.exe" -ErrorAction SilentlyContinue
            if (-not $adbExists) {
                Write-Host "[WARNING] adb.exe is not found in your system PATH." -ForegroundColor Yellow
                $dlPrompt = Read-Host "Download Android Platform Tools automatically? (Y to download, N to exit, B to go back)"
                
                if ($dlPrompt -match '^[Bb]$') {
                    $currentState = "Step2_Source"
                    continue
                } elseif ($dlPrompt -match '^[Yy]$') {
                    Write-Host "Downloading Android Platform Tools. Hang tight..." -ForegroundColor Cyan
                    try {
                        $installDir = Join-Path $env:LOCALAPPDATA "Android"
                        $platformToolsDir = Join-Path $installDir "platform-tools"
                        $zipPath = Join-Path $env:TEMP "platform-tools.zip"
                        $url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
                        
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
                        
                        if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
                        
                        Write-Host "Extracting files..." -ForegroundColor Cyan
                        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
                        
                        # Update user PATH environment variable seamlessly
                        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
                        if ($userPath -notmatch [regex]::Escape($platformToolsDir)) {
                            $newPath = $userPath + ";$platformToolsDir"
                            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
                            $env:PATH += ";$platformToolsDir"
                        }
                        
                        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
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

            # Get connected devices
            $devicesRaw = adb devices
            $connectedDevices = @($devicesRaw -split "`r?`n" | Where-Object { $_ -match "`tdevice$" })

            if ($connectedDevices.Count -eq 0) {
                Write-Host "[ERROR] No Android devices detected. Ensure USB Debugging is on." -ForegroundColor Red
                Start-Process -FilePath "adb.exe" -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                
                $retryPrompt = Read-Host "Press B to go back to source menu, or Enter to exit"
                if ($retryPrompt -match '^[Bb]$') {
                    $currentState = "Step2_Source"
                    continue
                }
                exit
            }

            $targetDevice = ($connectedDevices[0] -split "`t")[0].Trim()
            Write-Host "[OK] Device detected: $targetDevice" -ForegroundColor Green
            Write-Host "`n[2] Scanning Input folder..." -ForegroundColor Cyan

            $bundleFiles = Get-ChildItem -Path $inputDir -Include *.apkm,*.apks,*.xapk,*.zip -Recurse

            if ($bundleFiles.Count -eq 0) {
                Write-Host "[INFO] No bundle files found in the Input folder." -ForegroundColor Yellow
                Start-Process -FilePath "adb.exe" -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
                
                $emptyPrompt = Read-Host "Press B to go back or Enter to exit"
                if ($emptyPrompt -match '^[Bb]$') {
                    $currentState = "Step2_Source"
                    continue
                }
                exit
            }

            Write-Host "Found $($bundleFiles.Count) bundle file(s). Target Source: $installerSource`n" -ForegroundColor Green

            foreach ($bundle in $bundleFiles) {
                Write-Host "------------------------------------------------------"
                Write-Host "Extracting and Installing: $($bundle.Name)" -ForegroundColor Magenta
                
                $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "abi_temp_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                
                try {
                    $tempZip = Join-Path $tempDir "temp_bundle.zip"
                    Copy-Item -Path $bundle.FullName -Destination $tempZip -Force
                    
                    Write-Host "  -> Extracting bundle..."
                    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
                    
                    $apkList = Get-ChildItem -Path $tempDir -Filter *.apk -Recurse
                    
                    if ($apkList.Count -eq 0) {
                        Write-Host "  -> [ERROR] No .apk files found inside this bundle. Skipping..." -ForegroundColor Red
                        continue
                    }
                    
                    Write-Host "  -> Found $($apkList.Count) APK fragments. Starting installation..."
                    
                    # Build ADB arguments array WITH fake installer source
                    $adbArgs = @("-s", $targetDevice, "install-multiple", "-i", $installerSource)
                    foreach ($apk in $apkList) {
                        $adbArgs += $apk.FullName
                    }
                    
                    $installProc = Start-Process -FilePath "adb.exe" -ArgumentList $adbArgs -NoNewWindow -Wait -PassThru
                    
                    if ($installProc.ExitCode -eq 0) {
                        Write-Host "  -> [OK] App installed successfully." -ForegroundColor Green
                    } else {
                        Write-Host "  -> [ERROR] Failed to install app. Check connection or storage." -ForegroundColor Red
                    }
                    
                    if ($null -ne $installProc) { $installProc.Dispose() }
                    
                    # Process OBB data if available
                    $obbFolder = Join-Path $tempDir "Android\obb"
                    if (Test-Path $obbFolder) {
                        $obbItems = Get-ChildItem -Path $obbFolder -Directory
                        foreach ($obbAppFolder in $obbItems) {
                            Write-Host "  -> Found OBB data. Pushing $($obbAppFolder.Name) to device..."
                            $pushArgs = @("-s", $targetDevice, "push", $obbAppFolder.FullName, "/sdcard/Android/obb/")
                            $pushProc = Start-Process -FilePath "adb.exe" -ArgumentList $pushArgs -NoNewWindow -Wait -PassThru
                            
                            if ($null -ne $pushProc) { $pushProc.Dispose() }
                            Write-Host "  -> [OK] OBB transfer complete." -ForegroundColor Green
                        }
                    }
                    
                } catch {
                    Write-Host "  -> [FATAL ERROR] An error occurred while processing $($bundle.Name): $_" -ForegroundColor Red
                } finally {
                    if (Test-Path $tempDir) {
                        Write-Host "  -> Cleaning up temporary files..."
                        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            Write-Host "------------------------------------------------------"
            Write-Host "All tasks completed!" -ForegroundColor Cyan

            Write-Host "Releasing ADB background process..." -ForegroundColor DarkGray
            Start-Process -FilePath "adb.exe" -ArgumentList "kill-server" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

            $endPrompt = Read-Host "Press B to return to Main Menu, or Enter to exit"
            if ($endPrompt -match '^[Bb]$') {
                $currentState = "Step1_Ready"
                continue
            }
            exit
        }
    }
}