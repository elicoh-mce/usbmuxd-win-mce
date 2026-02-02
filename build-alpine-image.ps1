#Requires -Version 7.0
# Script to build Alpine WSL2 image with usbmuxd

$ErrorActionPreference = "Stop"

Write-Host "🏔️  Building Alpine WSL2 Image with usbmuxd`n" -ForegroundColor Cyan

# Configuration
$distroName = "alpine-usbmuxd-build"
$alpineDir = "$env:LOCALAPPDATA\wsl-alpine-usbmuxd"
$alpineUrl = "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz"
$alpineTar = "$env:TEMP\alpine-minirootfs.tar.gz"

# Step 1: Download Alpine
Write-Host "📥 Step 1: Downloading Alpine Linux..." -ForegroundColor Yellow
if (!(Test-Path $alpineTar)) {
    curl -L -o $alpineTar $alpineUrl
    Write-Host "✅ Downloaded Alpine Linux`n" -ForegroundColor Green
} else {
    Write-Host "✅ Alpine already downloaded`n" -ForegroundColor Green
}

# Step 2: Clean up any existing installation
Write-Host "🧹 Step 2: Cleaning up existing installation..." -ForegroundColor Yellow
try {
    wsl --unregister $distroName 2>$null
} catch {}
if (Test-Path $alpineDir) {
    Remove-Item -Recurse -Force $alpineDir
}
New-Item -ItemType Directory -Force -Path $alpineDir | Out-Null
Write-Host "✅ Cleaned up`n" -ForegroundColor Green

# Step 3: Import Alpine
Write-Host "📦 Step 3: Importing Alpine into WSL2..." -ForegroundColor Yellow
wsl --import $distroName $alpineDir $alpineTar --version 2
Write-Host "✅ Alpine imported`n" -ForegroundColor Green

# Step 4: Create build script
Write-Host "📝 Step 4: Creating build script..." -ForegroundColor Yellow
$buildScript = @'
#!/bin/sh
set -e

echo "==> Updating package index..."
apk update

echo "==> Installing build dependencies..."
apk add --no-cache \
    build-base \
    git \
    autoconf \
    automake \
    libtool \
    libusb-dev \
    libplist-dev \
    usbutils \
    linux-tools \
    pkgconfig \
    ca-certificates

echo "==> Building libimobiledevice-glue..."
cd /tmp
git clone https://github.com/libimobiledevice/libimobiledevice-glue.git
cd libimobiledevice-glue
./autogen.sh
make
make install

echo "==> Building usbmuxd..."
cd /tmp
git clone https://github.com/elicoh-mce/usbmuxd-win-mce.git
cd usbmuxd-win-mce
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
./autogen.sh
make
make install

echo "==> Cleaning up build artifacts..."
cd /
rm -rf /tmp/*
apk del build-base git autoconf automake libtool pkgconfig
apk cache clean

echo "==> Keeping only runtime dependencies..."
apk add --no-cache \
    libusb \
    libplist \
    usbutils \
    linux-tools

echo "==> Build complete!"
echo "usbmuxd version:"
usbmuxd --version || echo "usbmuxd installed at /usr/local/sbin/usbmuxd"
'@

$buildScript | wsl -d $distroName sh -c "cat > /tmp/build.sh && chmod +x /tmp/build.sh"
Write-Host "✅ Build script created`n" -ForegroundColor Green

# Step 5: Run build
Write-Host "🔨 Step 5: Building usbmuxd (this will take a few minutes)..." -ForegroundColor Yellow
Write-Host "    This step clones repos, compiles code, and installs usbmuxd" -ForegroundColor Gray
wsl -d $distroName /tmp/build.sh

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!`n" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build complete`n" -ForegroundColor Green

# Step 6: Export image
Write-Host "📤 Step 6: Exporting Alpine image..." -ForegroundColor Yellow
$exportPath = "$PSScriptRoot\alpine-usbmuxd.tar"
$gzPath = "$PSScriptRoot\alpine-usbmuxd.tar.gz"

if (Test-Path $exportPath) { Remove-Item $exportPath }
if (Test-Path $gzPath) { Remove-Item $gzPath }

wsl --export $distroName $exportPath
Write-Host "✅ Exported to $exportPath`n" -ForegroundColor Green

# Step 7: Compress
Write-Host "🗜️  Step 7: Compressing image..." -ForegroundColor Yellow
tar -czf $gzPath -C $PSScriptRoot alpine-usbmuxd.tar
Remove-Item $exportPath

$size = (Get-Item $gzPath).Length / 1MB
Write-Host "✅ Compressed to $gzPath ($([math]::Round($size, 2)) MB)`n" -ForegroundColor Green

# Summary
Write-Host "🎉 Alpine WSL2 image build complete!" -ForegroundColor Green
Write-Host "`nFiles created:" -ForegroundColor Cyan
Write-Host "  - $gzPath" -ForegroundColor White
Write-Host "`nWSL2 distribution:" -ForegroundColor Cyan
Write-Host "  - Name: $distroName" -ForegroundColor White
Write-Host "  - Location: $alpineDir" -ForegroundColor White
Write-Host "`nTo test the image:" -ForegroundColor Cyan
Write-Host "  wsl -d $distroName usbmuxd --version" -ForegroundColor White
Write-Host "`nTo remove the build distro:" -ForegroundColor Cyan
Write-Host "  wsl --unregister $distroName" -ForegroundColor White
