# 从腾讯云镜像安装 NDK 27.0.12077973（sdkmanager 直连 Google 失败时使用）
$ErrorActionPreference = "Stop"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\sdk" }
$dest = Join-Path $sdk "ndk\27.0.12077973"
$zip = Join-Path $sdk "android-ndk-r27-windows.zip"
$url = "https://mirrors.cloud.tencent.com/AndroidSDK/android-ndk-r27-windows.zip"

if (Test-Path (Join-Path $dest "source.properties")) {
    Write-Host "NDK 27 already installed: $dest"
    exit 0
}

Write-Host "Downloading NDK 27 from Tencent mirror..."
curl.exe -L --retry 3 --connect-timeout 30 -o $zip $url

Write-Host "Extracting..."
$tmp = Join-Path $sdk ".ndk_extract"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null
tar -xf $zip -C $tmp
New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
Move-Item (Join-Path $tmp "android-ndk-r27") $dest -Force
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Installed: $dest"
