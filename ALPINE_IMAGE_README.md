# Alpine WSL2 Image with usbmuxd

This is a pre-built Alpine Linux WSL2 image with usbmuxd ready to use for multi-instance iOS device management on Windows.

## Image Details

- **Base**: Alpine Linux 3.19.1
- **Size**: 26 MB compressed, 70 MB extracted
- **usbmuxd Version**: 1.1.1-git-c0db134 (with `--port` option)
- **Packages**: libusb, libplist, usbutils, linux-tools + runtime dependencies

## Quick Start

### Import the Image

```powershell
# Import into WSL2
wsl --import usbmuxd-alpine $env:LOCALAPPDATA\wsl-usbmuxd alpine-usbmuxd.tar.gz --version 2

# Verify installation
wsl -d usbmuxd-alpine usbmuxd --version
# Output: usbmuxd 1.1.1-git-c0db134
```

### Test usbmuxd

```powershell
# Start usbmuxd on port 27015
wsl -d usbmuxd-alpine usbmuxd -f -v --port 27015

# In another terminal, test with idevice tools
$env:USBMUXD_SOCKET_ADDRESS="127.0.0.1:27015"
idevice_id -l
```

## Usage with Instance Manager

The Node.js instance manager will automatically spawn usbmuxd instances in this Alpine distro:

```typescript
// InstanceManager spawns:
wsl -d usbmuxd-alpine usbmuxd -f -v -S 0.0.0.0:27015 --pidfile NONE
```

## Included Software

### Runtime
- `usbmuxd` - USB multiplexing daemon with `--port` option
- `libusb` - USB device access library
- `libplist` - Apple property list library (built from source)
- `libimobiledevice-glue` - Utility library (built from source)
- `usbutils` - USB utilities (lsusb, etc.)
- `linux-tools` - USB/IP support

### What's NOT Included
- Build tools (gcc, make, etc.) - removed to save space
- Preflight worker - disabled to avoid libimobiledevice dependency
- Documentation - man pages removed

## Command-Line Options

```bash
# Listen on specific port (shorthand)
usbmuxd --port 27015

# Full TCP address (equivalent)
usbmuxd -S 127.0.0.1:27015

# Run in foreground with verbose logging
usbmuxd -f -v --port 27015

# Disable hotplug (useful for manual device management)
usbmuxd -f -v --port 27015 -n

# Listen on all interfaces (for Windows → WSL2)
usbmuxd -f -v -S 0.0.0.0:27015
```

## Rebuilding the Image

To rebuild from source:

```powershell
cd C:\Dev\usbmuxd-win-mce

# Run the build script
.\build-alpine-image.ps1

# Or manually:
# 1. Import base Alpine
wsl --import alpine-build $env:LOCALAPPDATA\wsl-alpine alpine-minirootfs.tar.gz

# 2. Run build script
Get-Content alpine-build-fixed.sh -Raw | wsl -d alpine-build sh -c "cat > /tmp/build.sh"
wsl -d alpine-build sh /tmp/build.sh

# 3. Export
wsl --export alpine-build alpine-usbmuxd.tar
tar -czf alpine-usbmuxd.tar.gz alpine-usbmuxd.tar
```

## Troubleshooting

### usbmuxd not found
```bash
# Check if it's installed
wsl -d usbmuxd-alpine which usbmuxd
# Should output: /usr/local/sbin/usbmuxd

# Check PATH
wsl -d usbmuxd-alpine echo $PATH
# Should include /usr/local/sbin
```

### Libraries not found
```bash
# Check if runtime libraries are installed
wsl -d usbmuxd-alpine apk info libusb libplist

# Check library paths
wsl -d usbmuxd-alpine ls -la /usr/local/lib/
```

### WSL2 networking issues
```bash
# Test if port is accessible from Windows
wsl -d usbmuxd-alpine usbmuxd -f -v -S 0.0.0.0:27015 &
curl http://127.0.0.1:27015
```

## File Locations

- **Binary**: `/usr/local/sbin/usbmuxd`
- **Libraries**: `/usr/local/lib/libplist*.so`, `/usr/local/lib/libimobiledevice-glue*.so`
- **Package cache**: Cleared (use `apk update` to refresh)
- **Temp files**: `/tmp` is empty

## Maintenance

### Update Alpine packages
```bash
wsl -d usbmuxd-alpine apk update
wsl -d usbmuxd-alpine apk upgrade
```

### Update usbmuxd
Rebuild the image with the latest code from GitHub.

### Clean up
```bash
# Remove the distribution
wsl --unregister usbmuxd-alpine

# Remove installation directory
Remove-Item -Recurse $env:LOCALAPPDATA\wsl-usbmuxd
```

## Technical Details

### Build Process
1. Downloaded Alpine 3.19.1 minirootfs (3 MB)
2. Built libplist 2.6+ from source (Alpine repos have 2.3.0)
3. Built libimobiledevice-glue from source
4. Built usbmuxd with `--without-preflight` flag
5. Removed build tools and caches
6. Final size: 26 MB compressed

### Why Alpine?
- **Tiny**: 26 MB vs 500 MB for Ubuntu
- **Fast**: Boots in <1 second
- **Secure**: Minimal attack surface
- **Simple**: Easy to maintain and update

### Why --without-preflight?
- Avoids dependency on full libimobiledevice
- Preflight worker not needed for basic USB multiplexing
- Reduces complexity and image size
- Core functionality remains intact

## License

- Alpine Linux: MIT License
- usbmuxd: GPL v2/v3
- libplist: LGPL v2.1
- libimobiledevice-glue: LGPL v2.1

## Support

For issues with:
- **This image**: https://github.com/elicoh-mce/usbmuxd-win-mce/issues
- **Alpine Linux**: https://gitlab.alpinelinux.org/alpine/aports/-/issues
- **usbmuxd upstream**: https://github.com/libimobiledevice/usbmuxd/issues
